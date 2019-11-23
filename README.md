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
## Installation

You can find **Exnowflake** in [Hex.pm](https://hex.pm/packages/exnowflake) and you can add it to your project dependencies:

```elixir
# mix.exs
def deps do
  [
    {:exnowflake, "~> 0.1.0"}
  ]
end
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

### Ecto

If working with **Ecto**, you can create a custom type in order to autogenerate IDs:

```elixir
defmodule MyApp.Types.Exnowflake do
  @moduledoc """
  A custom Ecto type to generate Exnowflake IDs.
  """
  @behaviour Ecto.Type
  require Logger

  @type  t :: integer()

  @doc """
  Generates a new ID.
  """
  @spec generate() :: t()
  def generate do
    {:ok, id} = Exnowflake.generate()
    id
  rescue
    exeption ->
      Logger.error("Ecto type Exnowflake failed: #{inspect(exeption)}")
  end

  def autogenerate, do: generate()

  @impl true
  def type, do: :integer

  @impl true
  def cast(term) when is_integer(term), do: {:ok, term}
  def cast(_), do: :error

  @impl true
  def dump(term) when is_integer(term), do: {:ok, term}
  def dump(_), do: :error

  @impl true
  def load(term), do: {:ok, term}

  @impl true
  def equal?(term, term), do: true
  def equal?(_, _), do: false
end

```

Then in your schema you can configure the ID autogeneration:

```elixir
defmodule MyApp.User do
# ...
  @primary_key {:id, MyApp.Types.Exnowflake, autogenerate: true}
  alias MyApp.Types.Exnowflake
# ...
end
```
### Absinthe

When working with **Absinthe** (or any type of API for that matter), we should transform the **Integer** IDs to the **String** type. This because **JavaScript** does not support 64 bit integers and we'll get undesired behavior or errors.

```elixir
defmodule MyApp.Schema.ScalarTypes do
  @moduledoc """
  Custom Scalar types
  """
  use Absinthe.Schema.Notation

  @desc """
  `Exnowflake` type represents a 64 bit number, appears in JSON responses as a
  UTF-8 String due to Javascript's lack of support for  numbers > 53-bits.
  Its parsed again to an integer after received.
  """
  scalar :exnowflake, name: "Exnowflake" do
    serialize(&Integer.to_string/1)
    parse(&decode_exnowflake/1)
  end


  @spec decode_exnowflake(struct()) :: {:ok, integer()} | {:ok, nil} | :error
  defp decode_exnowflake(%Absinthe.Blueprint.Input.String{value: value}) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      _error -> :error
    end
  end
  defp decode_exnowflake(%Absinthe.Blueprint.Input.Integer{value: value}), do: {:ok, value}
  defp decode_exnowflake(%Absinthe.Blueprint.Input.Null{}), do: {:ok, nil}
  defp decode_exnowflake(_), do: :error
end

```

Now we can use the `:exnowflake` type for our IDs:

```elixir
# some schema query file
@desc "Fetches a User"
field :user, :user do
  arg :id, non_null(:exnowflake)
  resolve &MyApp.Users.get/2
end
```

*** If not using **Absinthe** (eg. REST API), similar procedures are recomended on server requests & responses.

## Benchmarks

Benchmarks can be run with: `mix bench`.

These benchmarks were run with a **Redis** worker registry (no static worker ID given), on an iMac 4 GHz Intel Core i7 w/ 32GB RAM.

```shell
Name                ips        average  deviation         median         99th %
generate       283.71 K        3.52 μs   ±414.17%           3 μs           5 μs
worker_id      622.99 K        1.61 μs   ±429.14%           2 μs           2 μs
```
