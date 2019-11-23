defmodule Exnowflake.TestCluster do
  @moduledoc """
  This module starts 3 slave nodes to run tests in a cluster environment.
  Example:
      mix test --include cluster
  """
  require Logger
  @node_names [:"exnow-1", :"exnow-2", :"exnow-3"]

  def start do
    IO.puts("==> Starting tests in cluster mode...")
    # Allow spawned nodes to fetch all code from this node
    :erl_boot_server.start([{127, 0, 0, 1}])

    results = @node_names
      |> Enum.map(fn node ->
        _spawn_node(node)
        :timer.sleep(50)
      end)

    IO.puts("==> Warming up...")
    Process.sleep(1_000) # Warm up
    IO.puts("==> Test cluster running...")
    {:ok, results}
  end

  def start_node(node) when is_atom(node) do
    _spawn_node(node)
  end

  def stop do
    Node.list(:connected)
    |> Enum.map(&Task.async(fn -> stop_node(&1) end))
    |> Enum.map(&Task.await(&1, 10_000))
  end

  def stop_node(node) do
    :ok = :slave.stop(node)
  end

  # =================
  # Private Functions
  # =================

  defp _spawn_node(node_host) do
    {:ok, node} = :slave.start('127.0.0.1', node_host, _slave_args())
    _set_up_node(node)
    {:ok, node}
  end

  defp _slave_args do
    '-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()} -logger level #{Logger.level()}'
  end

  defp _rpc(node, module, fun, args) do
    :rpc.block_call(node, module, fun, args)
  end

  defp _set_up_node(node) do
    _add_code_paths(node)
    _transfer_configuration(node)
    _ensure_applications_started(node)
  end

  defp _add_code_paths(node) do
    _rpc(node, :code, :add_paths, [:code.get_path()])
  end

  defp _transfer_configuration(node) do
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        _rpc(node, Application, :put_env, [app_name, key, val])
      end
    end
  end

  defp _ensure_applications_started(node) do
    _rpc(node, Application, :ensure_all_started, [:mix])
    _rpc(node, Mix, :env, [Mix.env()])

    for {app_name, _, _} <- Application.loaded_applications() do
      _rpc(node, Application, :ensure_all_started, [app_name])
    end
  end
end
