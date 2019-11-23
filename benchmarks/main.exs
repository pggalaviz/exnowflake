{:ok, _} = Application.ensure_all_started(:exnowflake)

benchmarks = %{
  "worker_id" => fn ->
    Exnowflake.worker_id()
  end,
  "generate" => fn ->
    Exnowflake.generate()
  end,
  "timestamp" => fn ->
    Exnowflake.timestamp(234_527_838_437_376)
  end
}

Benchee.run(benchmarks, [
  formatters: [
    {Benchee.Formatters.Console, comparison: false, extended_statistics: true}
  ],
  print: [
    fast_warning: false
  ]
])
