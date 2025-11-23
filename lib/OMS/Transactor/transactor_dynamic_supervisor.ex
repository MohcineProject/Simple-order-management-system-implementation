defmodule TransactorDynamicSupervisor do

  use DynamicSupervisor


  def start_link(_init_arg) do
    DynamicSupervisor.start_link( __MODULE__ , [] , name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init([strategy: :one_for_one])
  end
end
