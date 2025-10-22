defmodule TransactorAbstraction do
  @moduledoc """
  This module provides a way to create and process orders.

  It uses the MicroDb.HashTable module to store orders in memory.
  """

  @doc """
  Creates a new order.

  It takes an order as a map with the following keys:
    - "id"
    - "products"
  The "products" key should contain a list of products.
  Each product should be a map with the following keys:
    - "id"
    - "quantity"

  It finds the first store that has all the products in stock and
  assigns it to the order.

  It then stores the order in memory and returns the updated order.
  """
  def create(order) do
    selected_store = Enum.find(1..200,fn store_id->
      Enum.all?(order["products"],fn %{"id"=>prod_id,"quantity"=>q}->
        case MicroDb.HashTable.get("stocks",{store_id,prod_id}) do
          nil-> false
          store_q when store_q >= q-> true
          _-> false
        end
      end)
    end)
    updated_order = Map.put(order,"store_id",selected_store)
    MicroDb.HashTable.put("orders",order["id"],updated_order)
    {:ok ,updated_order}
  end

  @doc """
  Processes a payment for an order.

  It takes an order as a map with an "id" key.

  It also takes a transaction_id as a string.

  It updates the order with the transaction_id and stores it in memory.

  It then returns the updated order.
  """
  def checkout( order, transaction_id) do
    case MicroDb.HashTable.get("orders",order["id"]) do
      nil-> {:error , "Unknown order" }
      order->
        if Map.has_key?(order , "store_id") do
          {:error , "Order not created"}
        end
        updated_order = Map.put(order,"transaction_id",transaction_id)
        MicroDb.HashTable.put("orders",order["id"],order)
        {:ok , updated_order}
    end
  end

end
