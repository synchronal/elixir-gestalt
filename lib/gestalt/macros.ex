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

  @spec gestalt_config(module(), atom(), pid()) :: Macro.t()
  defmacro gestalt_config(module, key, pid) do
    if Mix.env() == :test do
      quote location: :keep do
        Gestalt.get_config(unquote(module), unquote(key), unquote(pid))
      end
    else
      quote location: :keep do
        unquote(pid)
        Application.get_env(unquote(module), unquote(key))
      end
    end
  end

  @spec gestalt_env(binary(), pid()) :: Macro.t()
  defmacro gestalt_env(variable, pid) do
    if Mix.env() == :test do
      quote location: :keep do
        Gestalt.get_env(unquote(variable), unquote(pid))
      end
    else
      quote location: :keep do
        unquote(pid)
        System.get_env(unquote(variable))
      end
    end
  end
end
