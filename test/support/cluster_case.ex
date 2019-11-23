defmodule Exnowflake.ClusterCase do
  @moduledoc """
  Module to set up clustered environment tests
  """
  use ExUnit.CaseTemplate
  @timeout 5000

  using do
    quote do
      import unquote(__MODULE__)
      @moduletag :cluster
      @timeout unquote(@timeout)
    end
  end

  def counter do
    System.unique_integer([:positive])
  end

  def nodes do
    Node.list()
  end

  def rpc(m, f, a \\ []) do
    nodes()
      |> Enum.random()
      |> :rpc.call(m, f, a)
  end

  def stop do
    nodes()
    |> Enum.map(&Task.async(fn -> stop_node(&1) end))
    |> Enum.map(&Task.await(&1, 10_000))
  end

  def stop_node(node) do
    :ok = :slave.stop(node)
  end
end
