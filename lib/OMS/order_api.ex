defmodule ImtOrder.API do
  use API.Exceptions
  use Plug.Router
  #plug Plug.Logger
  plug :match
  plug :dispatch

  import HashRingUpdatorInterface

  get "/aggregate-stats/:product" do
    IO.puts "get stat for #{product}"

    res =
      ImtOrder.StatsToDb.get(product)
       |> Enum.reduce(%{ca: 0, total_qty: 0}, fn {sold_qty,price}, acc ->
        %{acc|
          ca: acc.ca + sold_qty * price,
          total_qty: acc.total_qty + sold_qty
        }
      end)

    res = Map.put(res, :mean_price, res.ca / (if res.total_qty == 0, do: 1, else: res.total_qty))
    conn |> send_resp(200, Poison.encode!(res)) |> halt()
  end

  put "/stocks" do
    {:ok,bin,conn} = read_body(conn,length: 100_000_000)
    for line<-String.split(bin,"\n") do
      case String.split(line,",") do
        [_,_,_]=l->
          [prod_id,store_id,quantity] = Enum.map(l,&String.to_integer/1)
          MicroDb.HashTable.put("stocks",{store_id,prod_id},quantity)
        _-> :ignore_line
      end
    end
    conn |> send_resp(200,"") |> halt()
  end

  # Choose first store containing all products and send it the order !
  post "/order" do
    require Logger
    {:ok,bin,conn} = read_body(conn)
    order = Poison.decode!(bin)

    case order["id"] do
      nil ->
        Logger.error("[New Order] Missing order ID")
        conn |> send_resp(400, "Missing order ID") |> halt()
      order_id ->
        selected_node = getNode(order_id)
        case  :rpc.call(selected_node , TransactorInterface, :start, [order_id], 5000) do
          {:ok, _pid}  ->
            case :rpc.call(selected_node , TransactorInterface, :new_order , [order], 5000) do
              {:ok , _}->
                conn |> send_resp(200,"") |> halt()
            err ->
              Logger.error("[New Order] Error #{inspect err}")
              conn |> send_resp(500,"") |> halt()
            end
        err ->
            Logger.error("[Create] Error #{inspect err}")
            conn |> send_resp(500,"") |> halt()
        end
    end
  end



# payment arrived, get order and process package delivery !
post "/order/:orderid/payment-callback" do
  require Logger
  {:ok,bin,conn} = read_body(conn)
  %{"transaction_id"=> transaction_id} = Poison.decode!(bin)

  selected_node = getNode(orderid)

  case :rpc.call(selected_node , TransactorInterface, :start, [orderid], 5000) do
    {:ok, _pid} ->
            case :rpc.call(selected_node , TransactorInterface, :checkout, [orderid, transaction_id], 5000) do
              {:ok , _ }->
                  conn |> send_resp(200,"") |> halt()
              err ->
                Logger.error("[Payment] Error #{inspect err}")
                conn |> send_resp(500,"") |> halt()
            end
    error ->
        Logger.error("[Create] Error #{inspect error}")
        conn |> send_resp(500,"") |> halt()
  end
  end


end
