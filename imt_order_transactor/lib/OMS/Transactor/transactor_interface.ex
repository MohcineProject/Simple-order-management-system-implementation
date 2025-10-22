defmodule TransactorInterface do
  @moduledoc """
  The `TransactorInterface` module provides functions to start a transactor
  process and perform operations on orders such as creating a new order and
  processing a payment.
  """

  @doc """
  Starts a transactor process for a given `order_id`.

  Returns `{:ok, pid}` if the process is started successfully.
  Returns `{:ok, pid}` if the process is already started.
  Returns `{:error, reason}` if there is an error starting the process.
  """
  def start(order_id) do

    case DynamicSupervisor.start_child(TransactorDynamicSupervisor , {TransactorServer , order_id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Creates a new order by sending a `:new` message to the transactor process
  associated with the order's ID.

  Returns the result of the GenServer call.
  """
  def new_order(order) do
    GenServer.call({ :global, :"#{order["id"]}-Transactor"}, {:new, order})
  end

  @doc """
  Processes a payment for an order by sending a `:payment` message with the
  `transaction_id` to the transactor process associated with the order's ID.

  Returns the result of the GenServer call.
  """
  def checkout(transaction_id, order_id) do
    GenServer.call({ :global, :"#{order_id}-Transactor"}, {:payment, %{"transaction_id" => transaction_id}})
  end
end
