defmodule ImtSandbox.App do
  use Application

  def start(_, _) do
    # Ensure the "data" directory exists
    File.mkdir("data")
    # Use user input to choose weither to launch simulations or not
    case Node.self() |> Atom.to_string() |> String.split("-") do
      [_nodename, user_choice_with_host | _rest] ->
        # Further split to extract user choice
        [user_choice | _ ] = String.split(user_choice_with_host, "@")
        start_supervision_tree( user_choice)
      _ ->
        start_supervision_tree(nil)
    end
  end

  defp start_supervision_tree(user_choice) do
    # Choose child processes based on the user choice
    children_processes =
      case user_choice do
        "worker" ->
          IO.puts("\nStarting without simulations\n")
          [TransactorDynamicSupervisor]

        "master" ->
          IO.puts("\nStarting with simulations\n")
          [ImtOrder.App, TransactorDynamicSupervisor, ImtSim.WMS, ImtSim.EComFront]

        _ ->
          IO.puts("\nUsing the default configuration, starting without simulations\n")
          [TransactorDynamicSupervisor]
      end

    # Start the supervision tree
    Supervisor.start_link(children_processes, strategy: :one_for_one)
  end
end
