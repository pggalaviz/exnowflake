ExUnit.configure(exclude: [:cluster])


include = Keyword.get(ExUnit.configuration(), :include, [])
if :cluster in include do
  # Turn node into a distributed node with the given long name
  :net_kernel.start([:"test@127.0.0.1"])
  {:ok, _} = Exnowflake.TestCluster.start()
else
  IO.puts("==> Running tests on single node, to run on cluster mode with Redis add: --include cluster")
end

ExUnit.start()

ExUnit.after_suite(fn _result ->
  IO.puts("==> Cleaning Redis DB")
  {:ok, _} = GenServer.call(Exnowflake.Registry, :clean)

  IO.puts("==> Shutting down cluster nodes...")
  Exnowflake.TestCluster.stop()

  :timer.sleep(500)
  :ok
end)
