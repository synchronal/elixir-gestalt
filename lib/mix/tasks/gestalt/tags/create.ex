defmodule Mix.Tasks.Gestalt.Tags.Create do
  @moduledoc false

  use Mix.Task

  @shortdoc "Creates a git tag"
  @impl Mix.Task
  def run([]) do
    start_app!()

    Mix.Shell.IO.cmd(
      command()
      |> Enum.join(" ")
    )
  end

  defp command do
    [
      "git",
      "tag",
      "-a",
      tag(),
      "-m",
      "'#{description()}'"
    ]
  end

  defp description do
    Mix.Shell.IO.prompt("Please enter a tag message:")
  end

  defp tag do
    {:ok, version} = :application.get_key(:gestalt, :vsn)
    "v#{version}"
  end

  defp start_app!, do: Mix.Task.run("app.start", [])
end
