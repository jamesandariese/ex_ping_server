# PingServer

A GenServer which repeatedly pings itself on an interval.
Additionally, it can be pinged manually to accelerate the ping.

```
defmodule UsePing do
  use PingServer, interval: 10_000

  def start_link(thing) do
    # You can start link this way.  It will call PingServer.init(thing)
    PingServer.start_link(__MODULE__, thing, [])
  end

  def handle_ping(state) do
    # Even though the interval is 10 seconds, we can make it be every 1 second this way
    PingServer.ping_after(self(), 1_000)
    state
  end

  def handle_info(:manual_ping, state) do
    # only one ping will happen but it will happen pretty much right away.
    PingServer.ping(self())
    PingServer.ping(self())
    PingServer.ping(self())
    {:noreply, state}
  end
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_ping_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_ping_server, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_ping_server](https://hexdocs.pm/ex_ping_server).

