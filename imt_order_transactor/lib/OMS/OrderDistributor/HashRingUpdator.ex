defmodule HashRingUpdator do
  @moduledoc """
  This GenServer manages the hash ring used to distribute orders across nodes in the cluster.
  """

  use GenServer

  # Public API to start the GenServer
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Initializes the GenServer, enabling node monitoring and building the initial hash ring.
  """
  def init(_) do
    :net_kernel.monitor_nodes(true)
    {:ok, %{ring: build_ring()}}
  end

  @doc """
  Returns the node responsible for a given `order_id`.
  """
  def handle_call({:getNode, order_id}, _from, %{ring: ring} = state) do
    {:reply, find_node_in_ring(ring, order_id), state}
  end

  # Handle a node joining the cluster
  def handle_info({:nodeup, node}, %{ring: ring} = state) do
    IO.inspect("[HashRingUpdator] A node was added")
    new_ring = add_node(ring, node)
    {:noreply, %{state | ring: new_ring}}
  end

  # Handle a node leaving the cluster
  def handle_info({:nodedown, node}, %{ring: ring} = state) do
    IO.inspect("[HashRingUpdator] A node was removed")
    new_ring = remove_node(ring, node)
    {:noreply, %{state | ring: new_ring}}
  end


  # Builds the hash ring using the current nodes in the cluster.
  @spec build_ring() :: list({integer, atom})
  defp build_ring() do
    [Node.self() | Node.list()]
    |> Enum.map(fn node ->
      hash = rem(:erlang.phash2(node), 360)
      {hash, node}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end


  # Adds a node to the hash ring.
  defp add_node(ring, node) do
    new_ring = [{rem(:erlang.phash2(node), 360), node} | ring]
    Enum.sort_by(new_ring, &elem(&1, 0))
  end

  # Removes a node from the hash ring
  defp remove_node(ring, node) do
    ring
    |> Enum.reject(fn {_hash, n} -> n == node end)
  end

  # Finds the node responsible for a given `order_id`.
  @spec find_node_in_ring(list({integer, atom}), integer) :: atom
  defp find_node_in_ring(ring, order_id) do
    order_hash = rem(:erlang.phash2(order_id), 360)

    Enum.find(ring, fn {hash, _node} -> hash >= order_hash end)
    |> case do
      nil -> elem(List.first(ring), 1)
      {_hash, node} -> node
    end
  end

end

defmodule HashRingUpdatorInterface do
  @moduledoc """
  Provides a public interface for interacting with the HashRingUpdator GenServer.
  """

  @doc """
  Returns the node responsible for a given `order_id`.
  """
  def getNode(order_id) do
    GenServer.call(HashRingUpdator, {:getNode, order_id})
  end
end
