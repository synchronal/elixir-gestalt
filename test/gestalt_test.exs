defmodule GestaltTest do
  use ExUnit.Case, async: true
  doctest Gestalt

  describe "start/1" do
    test "starts a new agent" do
      refute GenServer.whereis(:start_agent)
      assert {:ok, agent} = Gestalt.start(:start_agent)
      assert ^agent = GenServer.whereis(:start_agent)
      Agent.stop(agent)
    end

    test "finds a running agent if it exists" do
      {:ok, agent} = Agent.start_link(fn -> %{} end, name: :running_agent)
      assert ^agent = GenServer.whereis(:running_agent)
      assert {:ok, ^agent} = Gestalt.start(:running_agent)
      Agent.stop(agent)
    end
  end

  describe "get_config/3" do
    test "verify Application env" do
      assert Application.get_env(:gestalt, :boolean_true) == true
      assert Application.get_env(:gestalt, :boolean_false) == false
      assert Application.get_env(:gestalt, :nil_value) == nil

      assert Application.get_env(:gestalt, :keyword_list) == [
               some: "thing",
               with: "multiple",
               set: "values"
             ]
    end

    test "raises when pid is not passed" do
      assert_raise RuntimeError, "get_config/3 must receive a pid", fn ->
        Gestalt.get_config(:thing, :blah, nil)
      end

      assert_raise RuntimeError, "get_config/3 must receive a pid", fn ->
        Gestalt.get_config(:thing, :blah, "pid")
      end
    end

    test "finds values from Application if the agent is not running" do
      refute GenServer.whereis(:not_running)

      assert Gestalt.get_config(:gestalt, :boolean_true, self(), :not_running) == true
      assert Gestalt.get_config(:gestalt, :boolean_false, self(), :not_running) == false
      assert Gestalt.get_config(:gestalt, :nil_value, self(), :not_running) == nil

      assert Gestalt.get_config(:gestalt, :keyword_list, self(), :not_running) ==
               [
                 some: "thing",
                 with: "multiple",
                 set: "values"
               ]
    end

    test "finds values from Application if the agent is running but there is no pid override" do
      {:ok, agent} = Gestalt.start(:get_config_value_no_override)

      assert Gestalt.get_config(:gestalt, :boolean_true, self(), :get_config_value_no_override) == true
      assert Gestalt.get_config(:gestalt, :boolean_false, self(), :get_config_value_no_override) == false
      assert Gestalt.get_config(:gestalt, :nil_value, self(), :get_config_value_no_override) == nil

      assert Gestalt.get_config(:gestalt, :keyword_list, self(), :get_config_value_no_override) ==
               [
                 some: "thing",
                 with: "multiple",
                 set: "values"
               ]

      Agent.stop(agent)
    end

    test "retrieves configuration from the running agent if there is a pid override" do
      pid = self()
      {:ok, agent} = Gestalt.start(:get_config_value_with_override)

      Agent.update(:get_config_value_with_override, fn state ->
        Map.put(state, pid, %{module: %{key: "value"}})
      end)

      assert Gestalt.get_config(:module, :key, pid, :get_config_value_with_override) == "value"

      Agent.stop(agent)
    end

    test "does not find any values from Application config if override is set" do
      pid = self()
      {:ok, agent} = Gestalt.start(:get_config_value_with_override)

      Agent.update(:get_config_value_with_override, fn state ->
        Map.put(state, pid, %{module: %{key: "value"}})
      end)

      assert Gestalt.get_config(:gestalt, :boolean_true, pid, :get_config_value_with_override) == nil

      Agent.stop(agent)
    end
  end

  describe "replace_config/4" do
    test "raises when pid is not passed" do
      assert_raise RuntimeError, "replace_config/4 must receive a pid", fn ->
        Gestalt.replace_config(:gestalt, :key, true, "self()")
      end
    end

    test "raises when no agent has been started" do
      refute GenServer.whereis(:replace_config_no_agent)

      assert_raise RuntimeError, "agent not started, please call start() before changing state", fn ->
        Gestalt.replace_config(:gestalt, :key, true, self(), :replace_config_no_agent)
      end
    end

    test "updates the agent when it is running" do
      pid = self()
      {:ok, agent} = Gestalt.start(:replace_config)

      assert Agent.get(:replace_config, fn state -> state end) == %{}
      Gestalt.replace_config(:gestalt, :key, true, pid, :replace_config)
      assert Agent.get(:replace_config, fn state -> state end) == %{pid => %{gestalt: %{key: true}}}

      Agent.stop(agent)
    end
  end
end
