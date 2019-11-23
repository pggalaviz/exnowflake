defmodule Exnowflake do
  @moduledoc """
  Exnowflake is an Elixir application used to generate decentralized, unique, time based IDs.
  """
  alias Exnowflake.{Worker, Registry}

  # Exnowflake.Registry
  defdelegate worker_id, to: Registry

  # Exnowflake.Worker
  defdelegate generate, to: Worker
  defdelegate timestamp(id), to: Worker
  defdelegate internal_timestamp(id), to: Worker
end
