defmodule TransactorServer do
  @moduledoc """
  A GenServer module responsible for managing transactions and processing
  orders based on their lifecycle, including initialization and handling
  calls for new orders and payments.
  """

  import TransactorAbstraction

  use GenServer


  # Starts the GenServer with a given order ID, setting a unique name per order
  # @param orderId - unique identifier for the order
  # @return PID of the GenServer process
  def start_link(orderId) do
    GenServer.start_link(__MODULE__, orderId, name: {:global,:"#{orderId}-Transactor"})
  end

  # Initializes the state of the GenServer with the order ID and an empty order
  # @param orderId - unique identifier for the order
  # @return Initial state map with orderId and a nil order
  def init(orderId) do
    {:ok, %{id: orderId, order: nil}}
  end

  # Handles a :new call to create a new order if it matches the orderId
  # @param {:new, order} - Tuple with action :new and order details
  # @param _from - Caller info (unused)
  # @param state - Current state, expected with orderId and a nil order
  # @return Reply with updated state if successful; stops GenServer otherwise
  def handle_call({:new, order}, _from, %{id: orderId, order: nil}) do
    case order["id"] do
      ^orderId ->  # Pattern match for valid order ID
        case create(order) do
          {:ok, updated_order} ->
            result = retry_request('http://localhost:9091/order/new' , 3 , 1000 , updated_order )
            {:reply, {:ok ,result} , %{id: orderId, order: updated_order}}
          {:error, reason} ->
            {:reply, {:error, reason}, %{id: orderId, order: nil}}
        end
      _ ->  # If order ID is mismatched, send an error message
        {:reply, {:error, "unregistered order"}, %{id: orderId, order: nil}}
    end
  end

  # Handles a :new call when an order already exists
  def handle_call({:new, order}, _from, %{id: orderId, order: existing_order}) do
    {:reply, {:error, "Order already exists"}, %{id: orderId, order: existing_order}}
  end

  # Handles a :payment call to process payment with a given transaction ID
  # @param {:payment, transaction} - Tuple with action :payment and transaction details
  # @param _from - Caller info (unused)
  # @param state - Current state, expected to contain the orderId and order details
  # @return Reply with updated state if payment is successful; stops GenServer otherwise
  def handle_call({:payment, %{"transaction_id" => transaction_id}}, _from, %{id: orderId, order: nil}) do
    {:reply, {:error, "Order not found"}, %{id: orderId, order: nil}}
  end

  def handle_call({:payment, %{"transaction_id" => transaction_id}}, _from, %{id: orderId, order: order}) do
    case checkout(orderId, transaction_id) do
      {:ok, updated_order} ->  # Payment successful, update the state with new order data
      result = retry_request('http://localhost:9091/order/process_delivery' , 3 , 1000 , updated_order)
        {:reply, {:ok ,result}, %{id: orderId, order: updated_order}}
      {:error, reason} ->  # Payment failed, send an error message
        {:reply , {:error, reason}, %{id: orderId, order: order}}
    end
  end


  # A helper function to retry sending a request using exponential backoff
  def retry_request(url , max_retries , time_delay , body) do
    require Logger
    if (max_retries == 0 ) do
      {:error , "Maximum retries reached"}

    else
    result = :httpc.request(
      :post,
      {url,[],'application/json',Poison.encode!(body)},
      [],
      [])
    retries_left = max_retries - 1
    case result do
      {:ok , _ } -> :ok
      _ ->
        Logger.warning("[Payment] process_delivery request to the backend failed, retrying ... (#{retries_left} retries left)")
        :timer.sleep(time_delay)
        retry_request(url , retries_left , time_delay*2 , body)
    end
  end
  end

end
