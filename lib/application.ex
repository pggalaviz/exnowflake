defmodule Exnowflake.Application do
  @moduledoc false
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("[exnowflake]: Starting application...")
    Exnowflake.Supervisor.start_link([])
  end
end
