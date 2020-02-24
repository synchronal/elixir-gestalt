defmodule Mix.Tasks.Git.Tags.Push do
  @moduledoc false

  use Mix.Task

  @shortdoc "Pushes all git tags"
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
