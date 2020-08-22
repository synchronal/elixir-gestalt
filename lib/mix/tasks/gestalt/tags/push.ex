defmodule Mix.Tasks.Gestalt.Tags.Push do
  @moduledoc false

  use Mix.Task

  @shortdoc "Pushes all git tags"
  @impl Mix.Task
  def run([]) do
    Mix.Shell.IO.cmd(command() |> Enum.join(" "))
  end

  defp command do
    [
      "git",
      "push",
      "origin",
      "--tags"
    ]
  end
end
