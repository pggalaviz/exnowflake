# Exnowflake

Exnowflake is an Elixir application used to generate decentralized, unique, time based IDs. It's inspired on Twitter's Snowflake.

## Description

This app generates 64 bit integers, based on a timestamp, worker ID and a sequence:

* timestamp (milliseconds) - 42 bits
* worker - 10 bits (0 - 1023)
* sequence - 12 bits (0 - 4095)

The worker ID can be an arbitrary integer between 0-1023, optionally a **Redis** connection should be configured to register/unregister nodes in order to get the worker number.

### Example

```elixir
=> {:ok, id} = Exnowflake.generate()
{:ok, 9522559057920}

=> Exnowflake.timestamp(id)
1565636645355
```

## Configuration

Example:

```elixir
config :exnowflake,
  worker_id: {:system, "WORKER_ID"}, # Must be an integer between 0-1023
  epoch: 1234567890 # custom epoch in milliseconds
```

##### *** Warning: if a custom `epoch` timestamp is given, it should not be reaplaced later or IDs overlap can occur.

If no `:worker_id` configuration option is given, **Exnowflake** will attempt to connect to **Redis** with the given defaults which you can override:

```elixir
config :exnowflake,
  host: "127.0.0.1",
  port: 6379,
  database: 0
```

You can also add the following options to redis connection:

```elixir
config :exnowflake,
  # ...other config options
  password: {:system, "REDIS_PWD"},
  ssl: true, # defaults to false
  sync_connect: false #defaults to true
```
For more info check [Redix Documentation](https://hexdocs.pm/redix/Redix.html#start_link/1).

## Usage

Generating an ID is very simple:

```elixir
=> {:ok, id} = Exnowflake.generate()
{:ok, 234527838437376}
```

We can also retrieve the timestamp inside the ID:

```elixir
=> Exnowflake.timestamp(id)
1574524265794
```

Or the internal timestamp, which returns how many milliseconds since `epoch`
passed when ID was generated:

```elixir
=> Exnowflake.internal_timestamp(id)
55915794
```
To get the current node worker ID, you can call:

```elixir
=> Exnowflake.worker_id()
0
```

## Benchmarks

Benchmarks can be run with: `mix bench`.

These benchmarks were run with a **Redis** worker registry (no static worker ID given), on an iMac 4 GHz Intel Core i7 w/ 32GB RAM.

```shell
Name                ips        average  deviation         median         99th %
generate       283.71 K        3.52 μs   ±414.17%           3 μs           5 μs
worker_id      622.99 K        1.61 μs   ±429.14%           2 μs           2 μs
```
