defmodule Exnowflake.RegistryTest do
  use ExUnit.Case, async: true
  alias Exnowflake.Registry

  # Exclude test when running in cluster mode.
  include = Keyword.get(ExUnit.configuration(), :include, [])
  if :cluster in include do
    @moduletag :skip
  end

  test "[local_registry]: returns the local registry" do
    assert [{n, _}] = Registry.local_registry()
    assert n == Kernel.node()
  end

  test "[redis_registry]: returns the Redis registry" do
    Process.sleep(500)
    assert [{n, _}] = Registry.redis_registry()
    assert n |> String.to_atom() == Kernel.node()
  end

  test "[machine_id]: returns machine number based on registration time." do
    assert 0 == Registry.worker_id()
  end
end

defmodule Exnowflake.RegistryClusterTest do
  use Exnowflake.ClusterCase, async: false
  alias Exnowflake.Registry

  test "[local_registry]: returns the local registry" do
    n = nodes() |> Enum.random()
    assert reg = Registry.local_registry()
    assert length(reg) == 3
    assert Keyword.has_key?(reg, n)
  end

  test "[redis_registry]: returns the Redis registry" do
    n = nodes() |> Enum.random()
    assert reg = Registry.local_registry()
    assert length(reg) == 3
    assert Keyword.has_key?(reg, n)
  end

  test "[worker_number]: returns machine number based on registration time." do
    Process.sleep(1000)
    n = nodes() |> Enum.random()
    index = Registry.local_registry()
      |> Enum.find_index(fn {key, _val} -> key == n end)

    assert index == :rpc.call(n, Registry, :worker_id, [])
  end
end
