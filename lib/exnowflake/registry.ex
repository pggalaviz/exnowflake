defmodule Exnowflake.Registry do
  @moduledoc """
  A Redis backed GenServer that exposes API for getting cluster machines registry.
  """
  use GenServer
  require Logger

  @connect_interval 1000
  @table :exnowflake_registry
  @registry_name "exnowflake:registry"
  @is_production if Mix.env() == :prod, do: true, else: false

  # ==========
  # Client API
  # ==========

  @doc """
  Returns all locally registered workers sorted by time.
  """
  @spec local_registry() :: keyword()
  def local_registry do
    @table
    |> :ets.tab2list()
    |> List.keysort(1)
  end

  @doc """
  Returns all Redis registered workers sorted by time.
  """
  @spec redis_registry() :: [{atom(), integer()}] | []
  def redis_registry do
    GenServer.call(__MODULE__, :registry)
  end

  @doc """
  Returns the current node worker number.
  """
  @spec worker_id() :: integer() | nil
  def worker_id do
    if id = Application.get_env(:exnowflake, :worker_id) do
      id
    else
      local_registry()
      |> Enum.find_index(fn {key, _val} -> key == Kernel.node() end)
    end
  end

  # ================
  # Server Callbacks
  # ================

  @doc false
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("[exnowflake][Registry]: Initializing...")
    Process.flag(:trap_exit, true)

    node_name = Kernel.node()

    # Validate Node name for production environment.
    if Mix.env() == :prod && (node_name in [nil, :nonode@nohost]) do
      raise RuntimeError, "[exnowflake]: A unique node name must be provided, received: #{node_name}"
    end

    # Create registry ETS
    :ets.new(@table, [:named_table, read_concurrency: true])

    state = %{
      name: node_name,
      time: System.os_time(:millisecond)
    }

    :ok = :net_kernel.monitor_nodes(true, [node_type: :all])

    Process.send_after(self(), :connect, 10)
    {:ok, state}
  end

  # Returns Redis current registry.
  @impl GenServer
  def handle_call(:registry, _from, state) do
    {:ok, set} = Redix.command(:exnowflake, ["ZRANGE", @registry_name, 0, -1, "WITHSCORES"])
    {:reply, _parse_set(set), state}
  rescue
    exeption ->
      Logger.error("[exnowflake][Registry]: #{inspect(exeption)}")
  end

  # Clear Redis registry on dev and test mode.
  @impl GenServer
  def handle_call(:clean, _from, state) do
    if @is_production do
      {:noreply, state}
    else
      {:reply, Redix.command(:exnowflake, ["DEL", @registry_name]), state}
    end
  end

  # Connects to every node in Redis registry, register or unregister accordingly.
  @impl GenServer
  def handle_info(:connect, state) do
    case _set_data(state) do
      {:ok, nodes} -> _connect_nodes(nodes)
      _other -> nil
    end

    Process.send_after(self(), :connect, @connect_interval)
    {:noreply, state}
  end

  # Called when new node is detected.
  @impl GenServer
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("[exnowflake][Registry]: Node up: #{node}")
    {:noreply, state}
  end

  # Called when node leaves cluster.
  @impl GenServer
  def handle_info({:nodedown, node, _info}, state) do
    Logger.info("[exnowflake][Registry]: Node down: #{node}")
    {:noreply, state}
  end

  # =================
  # Private Functions
  # =================

  # Add itself to Redis registry, then fetch it.
  defp _set_data(%{name: name, time: time}) do
    case Redix.transaction_pipeline(:exnowflake, [
      ["ZADD", @registry_name, time, name],
      ["ZRANGE", @registry_name, 0, -1, "WITHSCORES"]
    ]) do
      {:ok, [_, set]} ->
        :ets.insert(@table, {name, time})
        {:ok, _parse_set(set)}

      error ->
        Logger.error("[exnowflake][Registry]: error while fething Redis registry: #{inspect(error)}")
        error
    end
  end

  # Connect to each node or unregister it if unavailable.
  defp _connect_nodes(nodes) do
    node = Kernel.node()
    for {name, time} <- nodes do
      atom_name = String.to_atom(name)
      if atom_name != node do
        case Node.connect(atom_name) do
          true ->
            :ets.insert(@table, {atom_name, time})
            nil

          false ->
            _unregister(name, atom_name)

          _other ->
            nil
        end
      else
        :ets.insert(@table, {atom_name, time})
      end
    end
  end

  # Unregister a node from Redis and local registry.
  defp _unregister(name, atom_name) do
    case Redix.command(:exnowflake, ["ZREM", @registry_name, name]) do
      {:ok, _} ->
        :ets.delete(@table, atom_name)
        nil

      error ->
        Logger.error("[exnowflake][Registry]: error while unregistering node #{name}: #{inspect(error)}")
        nil
    end
  end

  defp _parse_set(set) when is_list(set) do
    set
    |> Enum.chunk_every(2)
    |> Enum.map(fn [name, score] -> {name, score} end)
    |> Enum.to_list()
  end
  defp _parse_set(_), do: []
end
