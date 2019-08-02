defmodule Gestalt do
  @moduledoc """
  Provides a wrapper for `Application.get_env/3` and `System.get_env/1`, where configuration
  can be overridden on a per-process basis. This allows asynchronous tests to change
  configuration on the fly without altering global state for other tests.


  ## Usage

  In `test_helper.exs`, add the following:

      {:ok, _} = Gestalt.start()

  In runtime code, where one would use `Application.get_env/3`,

      value = Application.get_env(:my_module, :my_config)

  instead the following could be used:

      value = Gestalt.get_config(:my_module, :my_config, self())

  In runtime code, where one would use `System.get_env/1`,

      value = System.get_env("VARIABLE_NAME")

  instead the following could be used:

      value = Gestalt.get_env("VARIABLE_NAME", self())


  ## Overriding values in tests

  The value of Gestalt comes from its ability to change configuration and/or environment
  in a way that only effects the current process. For instance, if code behaves differently
  depending on configuration, then a test that uses `Application.put_env/4` to verify its
  effect will change global state for other asynchronously-running tests.

  To change Application configuration, use the following:

      Gestalt.replace_config(:my_module, :my_value, "some value", self())

  To change System environment, use the following:

      Gestalt.replace_env("VARIABLE_NAME", "some value", self())


  ## Caveats

  Gestalt does not try to be too smart about merging overrides with existing configuration.
  If an override is set for the current pid, then all config and env values required by the
  runtime code must be specifically set.

  Also, note that Gestalt is a runtime configuration library. Values used by module variables
  are evaluated at compile time, not at runtime.

  """

  alias Gestalt.Util

  defmacro __using__(_) do
    quote do
      import Gestalt.Macros
    end
  end

  @doc ~S"""
  Starts an agent for storing override values. If an agent is already running, it
  is returned.

  ## Examples

      iex> {:ok, pid} = Gestalt.start()
      iex> is_pid(pid)
      true
      iex> {:ok, other_pid} = Gestalt.start()
      iex> pid == other_pid
      true

  """
  def start(agent \\ __MODULE__) do
    case GenServer.whereis(agent) do
      nil -> Agent.start_link(fn -> %{} end, name: agent)
      server -> {:ok, server}
    end
  end

  @doc ~S"""
  Gets configuration either from Application, or from the running agent.

  ## Examples

      iex> {:ok, _pid} = Gestalt.start()
      iex> Application.put_env(:module_name, :key_name, true)
      iex> Gestalt.get_config(:module_name, :key_name, self())
      true
      iex> Gestalt.replace_config(:module_name, :key_name, false, self())
      :ok
      iex> Gestalt.get_config(:module_name, :key_name, self())
      false

  """
  def get_config(_module, _key, _pid, _agent \\ __MODULE__)

  def get_config(module, key, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil -> Application.get_env(module, key)
      _ -> get_agent_config(agent, pid, module, key)
    end
  end

  def get_config(_module, _key, _pid, _agent), do: raise("get_config/3 must receive a pid")

  @doc ~S"""
  Gets environment variables either from System, or from the running agent.

  ## Examples

      iex> {:ok, _pid} = Gestalt.start()
      iex> System.put_env("VARIABLE_FROM_ENV", "value set from env")
      iex> Gestalt.get_env("VARIABLE_FROM_ENV", self())
      "value set from env"
      iex> Gestalt.replace_env("VARIABLE_FROM_ENV", "no longer from env", self())
      :ok
      iex> Gestalt.get_env("VARIABLE_FROM_ENV", self())
      "no longer from env"

  """
  def get_env(_variable, _pid, _agent \\ __MODULE__)

  def get_env(variable, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil -> System.get_env(variable)
      _ -> get_agent_env(agent, pid, variable)
    end
  end

  def get_env(_variable, _pid, _agent), do: raise("get_env/2 must receive a pid")

  ##############################
  ## Modify state
  ##############################

  @doc ~S"""
  Sets an override for the provided pid, effecting the behavior of `get_config/4`.
  """
  def replace_config(_module, _key, _value, _pid, _agent \\ __MODULE__)

  def replace_config(module, key, value, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil ->
        raise "agent not started, please call start() before changing state"

      _ ->
        Agent.update(agent, fn state ->
          update_map = %{module => %{key => value}}

          overrides =
            (get_in(state, [pid]) || [configuration: %{}])
            |> Keyword.update(:configuration, update_map, &Util.Map.deep_merge(&1, update_map))

          Map.put(state, pid, overrides)
        end)
    end
  end

  def replace_config(_module, _key, _value, _pid, _agent), do: raise("replace_config/4 must receive a pid")

  @doc ~S"""
  Sets an override for the provided pid, effecting the behavior of `get_env/3`.
  """
  def replace_env(_variable, _value, _pid, _agent \\ __MODULE__)

  def replace_env(variable, value, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil ->
        raise "agent not started, please call start() before changing state"

      _ ->
        Agent.update(agent, fn state ->
          overrides =
            (get_in(state, [pid]) || [env: %{}])
            |> Keyword.update(:env, %{variable => value}, &Map.put(&1, variable, value))

          Map.put(state, pid, overrides)
        end)
    end
  end

  def replace_env(_variable, _value, _pid, _agent), do: raise("replace_env/3 must receive a pid")

  ##############################
  ## Private
  ##############################

  defp get_agent_config(agent, caller_pid, module, key) do
    Agent.get(agent, fn state ->
      case get_in(state, [caller_pid, :configuration]) do
        nil -> Application.get_env(module, key)
        override -> get_in(override, [module, key])
      end
    end)
  end

  defp get_agent_env(agent, caller_pid, variable) when is_binary(variable) do
    Agent.get(agent, fn state ->
      case get_in(state, [caller_pid, :env]) do
        nil -> System.get_env(variable)
        override -> override[variable]
      end
    end)
  end
end
