# Checker

## Usage

```elixir
# Start the server
Checker.start(:my_server, interval: 5000)

# Add URL
Checker.add(:my_server, "https://github.com")
Checker.add(:my_server, "https://www.google.com")
Checker.add(:my_server, "https://unreachable234567894936743289.com")
Checker.add(:my_server, "https://github.com/fake_api_/")

# List URLs
Checker.list(:my_server)

# List URLs with certain status
Checker.list(:my_server, 200)
Checker.list(:my_server, 404)

# Stop seeing messages
Checker.debug(:none)

# Get the status of a URL
Checker.status(:my_server, "https://github.com")

# Delete URL
Checker.delete(:my_server, "https://github.com")

# Delete all URLs
Checker.reset(:my_server)

# Stop the server
Checker.stop(:my_server)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `checker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:checker, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/checker>.

