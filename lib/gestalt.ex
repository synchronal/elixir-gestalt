defmodule Gestalt do
  @moduledoc """
  Documentation for Gestalt.
  """

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
      _ -> get(agent, pid, module, key)
    end
  end

  def get_config(_module, _key, _pid, _agent), do: raise("get_config/3 must receive a pid")

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
          Map.put(state, pid, %{module => %{key => value}})
        end)
    end
  end

  def replace_config(_module, _key, _value, _pid, _agent), do: raise("replace_config/4 must receive a pid")

  ##############################
  ## Private
  ##############################

  defp get(agent, caller_pid, module, key) do
    Agent.get(agent, fn state ->
      case state[caller_pid] do
        nil -> Application.get_env(module, key)
        _ -> get_in(state, [caller_pid, module, key])
      end
    end)
  end
end
