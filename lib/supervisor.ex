defmodule Exnowflake.Supervisor do
  @moduledoc false
  use Supervisor

  @defaults [host: "127.0.0.1", port: 6379, database: 0, sync_connect: true]
  @redis_opts [:host, :port, :password, :database, :sync_connect, :ssl]

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    options = Application.get_all_env(:exnowflake)

    children = _check_machine_id(options)
    |> Enum.reject(&is_nil/1)
    |> Kernel.++([
      {Exnowflake.Worker, options}
    ])

    Supervisor.init(children, strategy: :one_for_one)
  end

  # =================
  # Private Functions
  # =================

  defp _check_machine_id(options) do
    unless Keyword.has_key?(options, :worker_id) do
      opts = Keyword.merge(@defaults, options)
      redis_opts = Keyword.take(opts, @redis_opts)
      [
        {Redix, Keyword.put(redis_opts, :name, :exnowflake)},
        Exnowflake.Registry
      ]
    end
  end
end
