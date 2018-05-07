defmodule Gestalt.MixProject do
  use Mix.Project

  def project do
    [
      aliases: aliases(),
      app: :gestalt,
      deps: deps(),
      description: description(),
      elixir: "~> 1.6",
      package: package(),
      source_url: "https://github.com/sparta-science/elixir-gestalt",
      start_permanent: Mix.env() == :prod,
      version: "0.1.2"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  defp aliases do
    [
      "hex.publish": ["git.tags.create", "git.tags.push", "hex.publish"]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description() do
    """
    A wrapper for `Application.get_config` and `System.get_env` that makes it easy
    to swap in process-specific overrides. Among other things, this allows tests
    to provide async-safe overrides.
    """
  end

  defp package() do
    [
      licenses: ["MIT"],
      maintainers: ["Eric Saxby"],
      links: %{"GitHub" => "https://github.com/sparta-science/elixir-gestalt"}
    ]
  end
end
