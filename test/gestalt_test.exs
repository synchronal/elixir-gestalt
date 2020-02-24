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

    test "uses Application if the agent is not running" do
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

    test "uses Application if the agent is running but there is no pid override" do
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

    test "uses the running agent if there is a pid override" do
      pid = self()
      {:ok, agent} = Gestalt.start(:get_config_value_with_override)

      Agent.update(:get_config_value_with_override, fn state ->
        Map.put(state, pid, configuration: %{module: %{key: "value"}})
      end)

      assert Gestalt.get_config(:module, :key, pid, :get_config_value_with_override) == "value"

      Agent.stop(agent)
    end

    test "does not use Application if agent override is set" do
      pid = self()
      {:ok, agent} = Gestalt.start(:get_config_value_with_override)

      Agent.update(:get_config_value_with_override, fn state ->
        Map.put(state, pid, configuration: %{module: %{key: "value"}})
      end)

      assert Gestalt.get_config(:gestalt, :boolean_true, pid, :get_config_value_with_override) == nil

      Agent.stop(agent)
    end
  end

  describe "get_env/2" do
    test "raises when pid is not passed" do
      assert_raise RuntimeError, "get_env/2 must receive a pid", fn ->
        Gestalt.get_env("VARIABLE", nil)
      end

      assert_raise RuntimeError, "get_env/2 must receive a pid", fn ->
        Gestalt.get_env("VARIABLE", "self()")
      end
    end

    test "uses System if the agent is not running" do
      refute GenServer.whereis(:not_running)

      System.put_env("VARIABLE_AGENT_NOT_RUNNING", "exists")
      assert Gestalt.get_env("VARIABLE_AGENT_NOT_RUNNING", self(), :not_running) == "exists"
    end

    test "uses System if the agent is running but there is no pid override" do
      {:ok, agent} = Gestalt.start(:get_env_value_no_override)

      System.put_env("VARIABLE_AGENT_RUNNING", "definitely exists")
      assert Gestalt.get_env("VARIABLE_AGENT_RUNNING", self(), :not_running) == "definitely exists"

      Agent.stop(agent)
    end

    test "uses the running agent if there is a pid override" do
      pid = self()
      {:ok, agent} = Gestalt.start(:get_env_value_with_override)

      System.put_env("VARIABLE_OVERRIDE", "i am from the system")

      Agent.update(:get_env_value_with_override, fn state ->
        Map.put(state, pid, env: %{"VARIABLE_OVERRIDE" => "i am overridden"})
      end)

      assert Gestalt.get_env("VARIABLE_OVERRIDE", pid, :get_env_value_with_override) == "i am overridden"

      Agent.stop(agent)
    end

    test "does not use System if agent override is set" do
      pid = self()
      {:ok, agent} = Gestalt.start(:get_env_value_with_override)

      System.put_env("VARIABLE_OVERRIDE", "i am from the system")

      Agent.update(:get_env_value_with_override, fn state ->
        Map.put(state, pid, env: %{"OTHER_VARIABLE_OVERRIDE" => "i am overridden"})
      end)

      assert Gestalt.get_env("VARIABLE_OVERRIDE", pid, :get_env_value_with_override) == nil

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

    test "adds to a running agent" do
      pid = self()
      {:ok, agent} = Gestalt.start(:replace_config)

      assert Agent.get(:replace_config, fn state -> state end) == %{}
      Gestalt.replace_config(:gestalt, :key, true, pid, :replace_config)
      assert Agent.get(:replace_config, fn state -> state end) == %{pid => [configuration: %{gestalt: %{key: true}}]}

      Agent.stop(agent)
    end

    test "handles multiple overrides for the same module" do
      pid = self()
      {:ok, agent} = Gestalt.start(:multiple_overrides)

      Gestalt.replace_config(:some, :stuff, [host: "here"], pid, :multiple_overrides)
      Gestalt.replace_config(:some, :thing, "yay", pid, :multiple_overrides)
      Gestalt.replace_config(:some, :other_thing, "nay", pid, :multiple_overrides)

      assert Gestalt.get_config(:some, :other_thing, pid, :multiple_overrides) == "nay"
      assert Gestalt.get_config(:some, :thing, pid, :multiple_overrides) == "yay"
      assert Gestalt.get_config(:some, :stuff, pid, :multiple_overrides) == [host: "here"]

      Agent.stop(agent)
    end

    test "merges into a running agent with overrides" do
      pid = self()

      {:ok, agent} =
        Agent.start_link(
          fn ->
            %{pid => [configuration: %{gestalt: %{key: true}}]}
          end,
          name: :merge_config
        )

      assert Agent.get(:merge_config, fn state -> state end) == %{pid => [configuration: %{gestalt: %{key: true}}]}
      Gestalt.replace_config(:gestalt, :override, "yay", pid, :merge_config)
      Gestalt.replace_config(:other, :thing, "nay", pid, :merge_config)

      assert Agent.get(:merge_config, fn state -> state end) == %{
               pid => [
                 configuration: %{
                   gestalt: %{key: true, override: "yay"},
                   other: %{thing: "nay"}
                 }
               ]
             }

      Agent.stop(agent)
    end

    test "merges into a running agent with env overrides" do
      pid = self()

      {:ok, agent} =
        Agent.start_link(
          fn ->
            %{pid => [env: %{"SOME" => "override"}]}
          end,
          name: :merge_config
        )

      assert Agent.get(:merge_config, fn state -> state end) == %{pid => [env: %{"SOME" => "override"}]}
      Gestalt.replace_config(:gestalt, :key, "yay", pid, :merge_config)

      assert Agent.get(:merge_config, fn state -> state end) == %{
               pid => [
                 env: %{
                   "SOME" => "override"
                 },
                 configuration: %{
                   gestalt: %{key: "yay"}
                 }
               ]
             }

      Agent.stop(agent)
    end

    test "does not merge keyword lists" do
      pid = self()

      {:ok, agent} =
        Agent.start_link(
          fn ->
            %{pid => [configuration: %{gestalt: %{key: [with: "some", value: "list"]}}]}
          end,
          name: :merge_config_lists
        )

      assert Agent.get(:merge_config_lists, fn state -> state end) == %{pid => [configuration: %{gestalt: %{key: [with: "some", value: "list"]}}]}

      Gestalt.replace_config(:gestalt, :key, [a: "different", keyword: "list"], pid, :merge_config_lists)

      assert Agent.get(:merge_config_lists, fn state -> state end) == %{
               pid => [
                 configuration: %{
                   gestalt: %{key: [a: "different", keyword: "list"]}
                 }
               ]
             }

      Agent.stop(agent)
    end
  end

  describe "replace_env/3" do
    test "raises when pid is not passed" do
      assert_raise RuntimeError, "replace_env/3 must receive a pid", fn ->
        Gestalt.replace_env("SOME_VARIABLE", true, "self()")
      end
    end

    test "raises when no agent has been started" do
      refute GenServer.whereis(:replace_env_no_agent)

      assert_raise RuntimeError, "agent not started, please call start() before changing state", fn ->
        Gestalt.replace_env("SOME_VARIABLE", true, self(), :replace_env_no_agent)
      end
    end

    test "adds to a running agent" do
      pid = self()
      {:ok, agent} = Gestalt.start(:replace_env)

      assert Agent.get(:replace_env, fn state -> state end) == %{}
      Gestalt.replace_env("REPLACING_VARIABLE", "overridden value", pid, :replace_env)
      assert Agent.get(:replace_env, fn state -> state end) == %{pid => [env: %{"REPLACING_VARIABLE" => "overridden value"}]}

      Agent.stop(agent)
    end

    test "merges into a running agent with overrides" do
      pid = self()

      {:ok, agent} =
        Agent.start_link(
          fn ->
            %{pid => [env: %{"EXISTING_OVERRIDE" => "something"}]}
          end,
          name: :merge_env
        )

      assert Agent.get(:merge_env, fn state -> state end) == %{pid => [env: %{"EXISTING_OVERRIDE" => "something"}]}
      Gestalt.replace_env("REPLACING_VARIABLE", "overridden value", pid, :merge_env)

      assert Agent.get(:merge_env, fn state -> state end) == %{
               pid => [
                 env: %{
                   "EXISTING_OVERRIDE" => "something",
                   "REPLACING_VARIABLE" => "overridden value"
                 }
               ]
             }

      Agent.stop(agent)
    end

    test "merges into a running agent with configuration overrides" do
      pid = self()

      {:ok, agent} =
        Agent.start_link(
          fn ->
            %{pid => [configuration: %{module: %{key: "value"}}]}
          end,
          name: :merge_env_into_config
        )

      assert Agent.get(:merge_env_into_config, fn state -> state end) == %{pid => [configuration: %{module: %{key: "value"}}]}
      Gestalt.replace_env("ENV_VAR", "value", pid, :merge_env_into_config)

      assert Agent.get(:merge_env_into_config, fn state -> state end) == %{
               pid => [
                 configuration: %{module: %{key: "value"}},
                 env: %{
                   "ENV_VAR" => "value"
                 }
               ]
             }

      Agent.stop(agent)
    end
  end

  describe "copy/2" do
    test "raises when no agent has been started" do
      refute GenServer.whereis(:copy_env_no_agent)

      assert_raise RuntimeError, "agent not started, please call start() before changing state", fn ->
        Gestalt.copy(self(), :erlang.list_to_pid('<0.1.0>'), :copy_env_no_agent)
      end
    end

    test "does nothing when no overrides exist for the source pid" do
      {:ok, agent} = Agent.start_link(fn -> %{} end, name: :copy_env_without_overrides)

      Gestalt.copy(self(), :erlang.list_to_pid('<0.1.0>'), :copy_env_without_overrides)
      assert Agent.get(:copy_env_without_overrides, fn state -> state end) == %{}

      Agent.stop(agent)
    end

    test "copies overrides to another pid" do
      pid = self()
      {:ok, agent} = Agent.start_link(fn -> %{} end, name: :copy_env)

      Gestalt.replace_env("ENV_VAR", "overridden value", self(), :copy_env)
      Gestalt.replace_config(:something, :key, true, self(), :copy_env)

      other_pid = :erlang.list_to_pid('<0.1.0>')
      Gestalt.copy(pid, other_pid, :copy_env)

      assert Agent.get(:copy_env, fn state -> state end) == %{
               pid => [
                 env: %{"ENV_VAR" => "overridden value"},
                 configuration: %{something: %{key: true}}
               ],
               other_pid => [
                 env: %{"ENV_VAR" => "overridden value"},
                 configuration: %{something: %{key: true}}
               ]
             }

      Agent.stop(agent)
    end
  end

  describe "copy!/2" do
    test "raises when no agent has been started" do
      refute GenServer.whereis(:copy_env_no_agent)

      assert_raise RuntimeError, "agent not started, please call start() before changing state", fn ->
        Gestalt.copy!(self(), :erlang.list_to_pid('<0.1.0>'), :copy_env_no_agent)
      end
    end

    test "raises when no overrides exist for the source pid" do
      pid = self()
      {:ok, agent} = Agent.start_link(fn -> %{} end, name: :copy_env_without_overrides)

      assert_raise RuntimeError, "copy!/2 expected overrides for pid: #{inspect(pid)}, but none found", fn ->
        Gestalt.copy!(pid, :erlang.list_to_pid('<0.1.0>'), :copy_env_without_overrides)
      end

      Agent.stop(agent)
    end

    test "copies overrides to another pid" do
      pid = self()
      {:ok, agent} = Agent.start_link(fn -> %{} end, name: :copy_env)

      Gestalt.replace_env("ENV_VAR", "overridden value", self(), :copy_env)
      Gestalt.replace_config(:something, :key, true, self(), :copy_env)

      other_pid = :erlang.list_to_pid('<0.1.0>')
      Gestalt.copy!(pid, other_pid, :copy_env)

      assert Agent.get(:copy_env, fn state -> state end) == %{
               pid => [
                 env: %{"ENV_VAR" => "overridden value"},
                 configuration: %{something: %{key: true}}
               ],
               other_pid => [
                 env: %{"ENV_VAR" => "overridden value"},
                 configuration: %{something: %{key: true}}
               ]
             }

      Agent.stop(agent)
    end
  end
end
