defmodule Gestalt do
  @moduledoc """
  Documentation for Gestalt.
  """

  alias Gestalt.Util

  def start(agent \\ __MODULE__) do
    case GenServer.whereis(agent) do
      nil -> Agent.start_link(fn -> %{} end, name: agent)
      server -> {:ok, server}
    end
  end

  def get_config(_module, _key, _pid, _agent \\ __MODULE__)

  def get_config(module, key, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil -> Application.get_env(module, key)
      _ -> get_agent_config(agent, pid, module, key)
    end
  end

  def get_config(_module, _key, _pid, _agent), do: raise("get_config/3 must receive a pid")

  def get_env(_varibale, _pid, _agent \\ __MODULE__)

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

  def replace_config(_module, _key, _value, _pid, _agent \\ __MODULE__)

  def replace_config(module, key, value, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil ->
        raise "agent not started, please call start() before changing state"

      _ ->
        Agent.update(agent, fn state ->
          overrides =
            (get_in(state, [pid, :configuration]) || %{})
            |> Util.Map.deep_merge(%{module => %{key => value}})

          Map.put(state, pid, configuration: overrides)
        end)
    end
  end

  def replace_config(_module, _key, _value, _pid, _agent), do: raise("replace_config/4 must receive a pid")

  def replace_env(_varibale, _value, _pid, _agent \\ __MODULE__)

  def replace_env(variable, value, pid, agent) when is_pid(pid) do
    case GenServer.whereis(agent) do
      nil ->
        raise "agent not started, please call start() before changing state"

      _ ->
        Agent.update(agent, fn state ->
          overrides =
            (get_in(state, [pid, :env]) || %{})
            |> Map.put(variable, value)

          Map.put(state, pid, env: overrides)
        end)
    end
  end

  def replace_env(_variable, _value, _pid, _agent), do: raise("replace_env/3 must receive a pid")

  ##############################
  ## Private
  ##############################

  defp get_agent_config(agent, caller_pid, module, key) do
    Agent.get(agent, fn state ->
      case state[caller_pid] do
        nil -> Application.get_env(module, key)
        _ -> get_in(state, [caller_pid, :configuration, module, key])
      end
    end)
  end

  defp get_agent_env(agent, caller_pid, variable) when is_binary(variable) do
    Agent.get(agent, fn state ->
      case state[caller_pid] do
        nil -> System.get_env(variable)
        _ -> get_in(state, [caller_pid, :env, variable])
      end
    end)
  end
end
