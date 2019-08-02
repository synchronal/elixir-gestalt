defmodule Gestalt.Macros do
  @moduledoc """
  Provides macros that execute Gestalt code only in the :test Mix environment.
  In other environments, Gestalt is compiled out and either Application or
  System is used.

  ## Usage

      defmodule MyApp.Config do
        use Gestalt

        def config_value(),
          do: gestalt_config(:my_app, :config, self())

        def env_value(),
          do: gestalt_env("ENVIRONMENT_VARIABLE", self())
      end
  """

  defmacro gestalt_config(module, key, pid) do
    if Mix.env() == :test do
      quote do
        Gestalt.get_config(unquote(module), unquote(key), unquote(pid))
      end
    else
      quote do
        unquote(pid) &&
          Application.get_env(unquote(module), unquote(key))
      end
    end
  end

  defmacro gestalt_env(variable, pid) do
    if Mix.env() == :test do
      quote do
        Gestalt.get_env(unquote(variable), unquote(pid))
      end
    else
      quote do
        unquote(pid) &&
          System.get_env(unquote(variable))
      end
    end
  end
end
