# Tailscale for Elixir

Elixir bindings for [Tailscale](https://tailscale.com), allowing you to embed Tailscale networking directly in your Elixir applications.

## Installation

The package can be installed by adding `tailscale` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tailscale, "~> 0.1.0"}
  ]
end
```

## Requirements

- Elixir 1.14 or later
- A C compiler (gcc or clang)
- libtailscale shared library (included in this repository)

## Usage

```elixir
# Create a new Tailscale instance
{:ok, ts} = Tailscale.new()

# Configure the instance
:ok = Tailscale.set_hostname(ts, "my-elixir-app")
:ok = Tailscale.set_ephemeral(ts, true)
:ok = Tailscale.set_auth_key(ts, "tskey-your-auth-key")

# Connect to Tailscale network (blocks until connected)
:ok = Tailscale.up(ts)

# Create a listener
{:ok, listener} = Tailscale.listen(ts, "tcp", ":8080")

# Accept connections (socket is a port/file descriptor)
{:ok, socket} = Tailscale.Listener.accept(listener)

# socket is already a port that can be used directly with :gen_tcp
# No need for additional conversion with :gen_tcp.connect

# Receive data
{:ok, data} = :gen_tcp.recv(socket, 0)

# Send data
:ok = :gen_tcp.send(socket, "Hello from Elixir!")

# Close everything when done
:ok = :gen_tcp.close(socket)
:ok = Tailscale.Listener.close(listener)
:ok = Tailscale.close(ts)
```

See the `examples` directory for more usage examples.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) by running:

```
mix docs
```

## License

This project is licensed under the BSD 3-Clause License - see the LICENSE file for details.
