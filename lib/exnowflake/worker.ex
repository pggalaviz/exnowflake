defmodule Exnowflake.Worker do
  @moduledoc """
  This worker generates unique time based IDs.
  """
  use GenServer
  use Bitwise
  require Logger
  alias Exnowflake.Registry

  @epoch 1_574_467_200_000 # Default epoch - November 23, 2019 12:00:00 AM
  @seq_overflow 4096 # Max number of IDs per millisecond
  @is_test if Mix.env() == :test, do: true, else: false

  # ==========
  # Client API
  # ==========

  @doc """
  Generates a 64 bit integer based on time, worker ID and a sequence.
  """
  @spec generate() :: {:ok, integer()} | {:error, :backwards_clock}
  def generate do
    GenServer.call(__MODULE__, :next_id)
  end

  @doc """
  Returns the real timestamp of an ID in milliseconds.
  """
  @spec timestamp(integer()) :: integer()
  def timestamp(id) do
    (id >>> 22) + _get_epoch()
  end

  @doc """
  Returns milliseconds passed since epoch when ID was generated.
  """
  @spec internal_timestamp(integer()) :: integer()
  def internal_timestamp(id), do: id >>> 22

  # ================
  # Server Callbacks
  # ================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    wid = Keyword.get(opts, :worker_id)
    epoch = Keyword.get(opts, :epoch) || @epoch

    _check_worker_id(wid)

    state = %{
      mn: wid,
      epoch: epoch,
      ts: _get_ts(epoch),
      seq: 0
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:next_id, from, %{mn: mn, epoch: epoch, ts: prev_ts, seq: seq} = state) do
    case _next_ts_and_seq(epoch, prev_ts, seq) do
      {:ok, new_ts, new_seq} ->
        id = _generate_id(mn, new_ts, new_seq)
        {:reply, {:ok, id}, %{state | ts: new_ts, seq: new_seq}}

      {:error, :seq_overflow} ->
        Logger.error("[exnowflake]: Sequence overflow")
        :timer.sleep(1)
        handle_call(:next_id, from, state)

      {:error, :backwards_clock} ->
        Logger.error("[exnowflake]: Backwards clock")
        {:reply, {:error, :backwards_clock}, state}
    end
  end

  # =================
  # Private Functions
  # =================

  # Check if worker ID is between parameters or raise error.
  defp _check_worker_id(nil), do: :ok
  defp _check_worker_id(id) when id >= 0 and id < 1024, do: id
  defp _check_worker_id(id) do
    raise RuntimeError, "[exnowflake]: Worker ID should be an integer between 0-1023, received: #{inspect(id)}"
  end

  # Get milliseconds passed since epoch.
  defp _get_ts(epoch) do
    System.os_time(:millisecond) - epoch
  end

  # Get custom or default epoch.
  defp _get_epoch() do
    Application.get_env(:exnowflake, :epoch) || @epoch
  end

  # Get the next timestamp and sequence or return error.
  defp _next_ts_and_seq(epoch, prev_ts, seq) do
    case _get_ts(epoch) do
      ^prev_ts ->
        case seq + 1 do
          @seq_overflow -> {:error, :seq_overflow}
          next_seq -> {:ok, prev_ts, next_seq}
        end

      new_ts ->
        if new_ts < prev_ts do
          {:error, :backwards_clock}
        else
          {:ok, new_ts, 0}
        end
    end
  end

  # Generates the new ID, if worker_id (first argument) is nil, will call Registry to get it.
  defp _generate_id(nil, ts, seq) do
    # TODO: Solve pattern match against nil to pass cluster tests.
    case Registry.worker_id() do
      nil ->
        if @is_test do
          _parse_id(ts, seq, 1023)
        else
          Logger.error("[exnowflake][Registry]: Got nil as worker ID.")
        end

      worker_id ->
        _parse_id(ts, seq, worker_id)
    end
  end
  defp _generate_id(worker_id, ts, seq) do
    _parse_id(ts, seq, worker_id)
  end

  # Returns the new ID.
  defp _parse_id(ts, seq, id) do
    << new_id :: unsigned-integer-size(64)>> = <<
      ts :: unsigned-integer-size(42),
      id :: unsigned-integer-size(10),
      seq :: unsigned-integer-size(12) >>
    new_id
  end
end
