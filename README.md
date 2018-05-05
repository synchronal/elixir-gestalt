Gestalt
=======

A wrapper for `Application.get_config` and `System.get_env` that makes it easy
to swap in process-specific overrides. Among other things, this allows tests
to provide async-safe overrides.

Documentation can be found at [https://hexdocs.pm/gestalt](https://hexdocs.pm/gestalt).

## Installation

This package can be installed by adding `gestalt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gestalt, "~> 0.1.0"}
  ]
end
```
