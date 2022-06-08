Overview
========

Gestalt serves as a wrapper for `Application.get_env/3` and `System.get_env/1`. It provides a mechanism for setting
process-specific overrides to application configuration and system variables, primarily to ease asynchronous testing of
behaviors dependent on specific values.

Gestalt should be used for getting runtime configuration, and not in places where configuration is compiled into
modules.


## Asynchronous Testing

Assuming your project sets configuration in `config.exs`, some elixir code will use `Application.get_env/3` to access
its values.

```elixir
use Mix.Config

config :my_project, :enable_new_feature, true
```

This could be accessed at runtime using a config module:

```elixir
defmodule Project.Config do
  def enable_new_feature? do
    Application.get_env(:my_project, :enable_new_feature)
  end
end
```

And tests could be written:

```elixir
defmodule Project.ConfigTest do
  use ExUnit.Case, async: true

  alias Project.Config

  describe "enable_new_feature?/0" do
    test "when :enable_new_feature is true, it is true" do
      :ok = Application.put_env(:my_project, :enable_new_feature, true)
      assert Config.enable_new_feature?()
    end

    test "when :enable_new_feature is false, it is false" do
      :ok = Application.put_env(:my_project, :enable_new_feature, false)
      refute Config.enable_new_feature?()
    end
  end
end
```

Now there is a problem. Because these tests are marked `async: true`, there will be times that they will run
concurrently. Since application env is global, `Application.put_env/4` will effect everything else in the runtime. If
controller tests or acceptance tests assert on user-facing behavior related to the configuration, then the two tests
shown above may cause those to fail randomly and non-deterministically.

The same problem occurs with `System.get_env/1`. Code may behave differently in the presence of a specific environment
variable. For instance, optionally initializing a library depending on whether or not an authentication token is
present. `System.put_env/2` can be used to update values for tests, leading to more non-deterministic test failures.

```elixir
defmodule Project.Config do
  #...

  def enable_monitoring_lib? do
    case monitoring_auth_token do
      nil -> false
      _ -> true
    end
  end

  def monitoring_auth_token do
    System.get_env("AUTH_TOKEN")
  end
end
```

```elixir
defmodule Project.ConfigTest do
  #...

  describe "enable_monitoring_lib?/0" do
    test "when AUTH_TOKEN is present, it is true" do
      :ok = System.put_env("AUTH_TOKEN", "abc123")
      assert Config.enable_monitoring_lib?()
    end

    test "when AUTH_TOKEN is not present, it is false" do
      :ok = System.delete_env("AUTH_TOKEN")
      refute Config.enable_monitoring_lib?()
    end
  end
end
```

One solution would be to set `async: false` for all tests that depend upon configuration. Another would be to rewrite
the `Config` functions such that `Application` or `System` could be injected. The former would work for testing at the
acceptance level. The second would not, without jumping through many more hoops of dependency injection.


## Pid-specific Overrides

Gestalt solves this problem in a different fashion, by starting an `Agent` to store override values for specific pids.
Initialization of the agent can be done in `test/test_helpers.exs`, for instance:

```elixir
{:ok, _agent} = Gestalt.start()
```

Now the config module can be rewritten as follows:

```elixir
defmodule Project.Config do
  def enable_new_feature? do
    Gestalt.get_config(:my_project, :enable_new_feature, self())
  end

  def enable_monitoring_lib? do
    case monitoring_auth_token do
      nil -> false
      _ -> true
    end
  end

  def monitoring_auth_token do
    Gestalt.get_env("AUTH_TOKEN", self())
  end
end
```

By default, when there is no agent running or when there are no overrides for the current pid, `Gestalt.get_config/4`
falls back to `Application.get_env/3` and `Gestalt.get_env/2` falls back to `System.get_env/1`. For purposes of clarity
and to remind us that Gestalt overrides are pid-specific, the pid arguments are not optional. Gestalt functions do take
an extra optional argument, which is the agent name.

Now our tests can be rewritten as follows to use `Gestalt.replace_config/5` and `Gestalt.replace_env/4`:

```elixir
defmodule Project.ConfigTest do
  use ExUnit.Case, async: true

  alias Project.Config

  describe "enable_new_feature?/0" do
    test "when :enable_new_feature is true, it is true" do
      :ok = Gestalt.replace_config(:my_project, :enable_new_feature, true, self())
      assert Config.enable_new_feature?()
    end

    test "when :enable_new_feature is false, it is false" do
      :ok = Gestalt.replace_config(:my_project, :enable_new_feature, false, self())
      refute Config.enable_new_feature?()
    end
  end

  describe "enable_monitoring_lib?/0" do
    test "when AUTH_TOKEN is present, it is true" do
      :ok = Gestalt.replace_env("AUTH_TOKEN", "abc123", self())
      assert Config.enable_monitoring_lib?()
    end

    test "when AUTH_TOKEN is not present, it is false" do
      :ok = Gestalt.replace_env("AUTH_TOKEN", nil, self())
      refute Config.enable_monitoring_lib?()
    end
  end
end
```

Note that `self()` can be used in both the code and the tests, because the code is running in the same pid as the test.
In most cases, this will be safe. In some few cases, the code might be running in a separate process from the test, in
which case `replace_config` and `replace_env` should use the pid of the running code.


## Runtime vs. Compile-time

Gestalt can be used to override values in the runtime. A common pattern in Elixir dependency injection is to use
application config to set module variables. This happens at compile time, making it impossible for Gestalt to
provide overrides.


## Gestalt macros for testing

For cases where runtime configuration should only be overridden during testing, Gestalt provides macros that compile
to `Application` and `System` in non-test environments.

```elixir
defmodule Project.Config do
  use Gestalt

  def enable_new_feature? do
    gestalt_config(:my_project, :enable_new_feature, self())
  end

  def enable_monitoring_lib? do
    case monitoring_auth_token do
      nil -> false
      _ -> true
    end
  end

  def monitoring_auth_token do
    gestalt_env("AUTH_TOKEN", self())
  end
end
``` 


## Acceptance tests

Acceptance tests often involve multiple processes. Wallaby, for instance, starts a Phoenix server, which processes
requests in separate processes. In this case, `self()` in the context of the test process will be different from
`self()` in the server process.

This can by solved with the `Gestalt.copy/2` function, in a test plug.

If the `test` Mix env includes `test/support` in its elixir paths, then a plug can be written in
`test/support/test/plug/gestalt.ex`

```elixir
defmodule ProjectWeb.Test.Plug.Gestalt do
  alias Plug.Conn

  def init(_), do: nil

  def call(conn, _opts),
    do:
      conn
      |> extract_metadata()
      |> copy_overrides(conn)

  defp extract_metadata(%Conn{} = conn),
    do:
      conn
      |> Conn.get_req_header("user-agent")
      |> List.first()
      |> Phoenix.Ecto.SQL.Sandbox.decode_metadata()

  defp copy_overrides(%{gestalt_pid: gestalt_pid}, conn) do
    Gestalt.copy(gestalt_pid, self())
    conn
  end

  defp copy_overrides(_metadata, conn), do: conn
end
```

This can then be added to the Phoenix Endpoint:

```elixir
defmodule ProjectWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_project

  if Application.get_env(:my_project, :sql_sandbox) do
    plug(Phoenix.Ecto.SQL.Sandbox)
    plug(ProjectWeb.Test.Plug.Gestalt)
  end
  
  # ....
end
```

In the `CaseTemplate` used for your acceptance tests, the following can then be configured (if using Wallaby):

```elixir
setup tags do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Project.Repo)
  unless tags[:async], do: Ecto.Adapters.SQL.Sandbox.mode(Project.Repo, {:shared, self()})

  # Add the :gestalt_pid test process pid to the metadata being passed through each acceptance request header
  metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Project.Repo, self()) |> Map.put(:gestalt_pid, self())
  {:ok, session} = Wallaby.start_session(metadata: metadata)
  {:ok, session: session}
end
```

Now, any overrides configured for the test process will be copied onto the server process pid, and
`Gestalt.get_config/3` or `Gestalt.get_env/2` will have your overrides available.


## LiveView tests

LiveView tests can be configured to share the Gestalt configuration via `Phoenix.LiveView.on_mount/1`.
In the test, the current pid should be added to the `conn`'s session.

```elixir
Phoenix.ConnTest.init_test_session(conn, %{gestalt_pid: self()})
{:ok, _live, _html} = live(conn, "/")
```

The LiveView can run an `on_mount` handler to copy configuration for the socket's pid.

```elixir
defmodule Web.Gestalt do
  def on_mount(:copy_gestalt_config, _params, %{"gestalt_pid" => gestalt_pid}, socket) do
    Gestalt.copy(gestalt_pid, self())
    {:cont, socket}
  end

  def on_mount(:copy_gestalt_config, _params, _session, socket) do
    {:cont, socket}
  end
end
```

```elixir
module Web.MyLive do
  use Web, :live_view

  on_mount {Web.Gestalt, :copy_gestalt_config}

  def render(assigns) do
    ~H"<div />"
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end
```
