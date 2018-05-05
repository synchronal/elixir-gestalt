Gestalt
=======

A wrapper for `Application.get_config` and `System.get_env` that makes it easy
to swap in process-specific overrides. Among other things, this allows tests
to provide async-safe overrides.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gestalt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gestalt, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/gestalt](https://hexdocs.pm/gestalt).
