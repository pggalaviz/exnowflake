defmodule Exnowflake.WorkerTest do
  use ExUnit.Case, async: true
  alias Exnowflake.Worker

  test "[generate]: geneartes a new ID" do
    assert {:ok, id1} = Worker.generate()
    assert {:ok, id2} = Worker.generate()
    assert id1 < id2
  end

  test "[timestamp]: returns the timestamp inside an ID" do
    assert {:ok, id1} = Worker.generate()
    assert {:ok, id2} = Worker.generate()
    assert ts1 = Worker.timestamp(id1)
    assert ts2 = Worker.timestamp(id2)
    assert ts1 <= ts2
  end

  test "[internal_timestamp]: returns milliseconds passed since epoch" do
    assert {:ok, id1} = Worker.generate()
    assert {:ok, id2} = Worker.generate()
    assert ts1 = Worker.internal_timestamp(id1)
    assert ts2 = Worker.internal_timestamp(id2)
    assert ts1 <= ts2
  end
end

defmodule Exnowflake.WorkerClusterTest do
  use Exnowflake.ClusterCase, async: false
  alias Exnowflake.Worker

  test "[generate]: geneartes a new ID" do
    assert {:ok, id1} = rpc(Worker, :generate)
    assert {:ok, id2} = rpc(Worker, :generate)
    assert id1 != id2
  end
end
