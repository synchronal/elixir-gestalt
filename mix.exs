defmodule Gestalt.MixProject do
  use Mix.Project

  @version "2.0.0"

  def project do
    [
      aliases: aliases(),
      app: :gestalt,
      deps: deps(),
      description: description(),
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.15",
      package: package(),
      source_url: "https://github.com/synchronal/elixir-gestalt",
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  def cli,
    do: [
      preferred_envs: [credo: :test, dialyzer: :test]
    ]

  # # #

  defp aliases,
    do: []

  defp deps,
    do: [
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mix_audit, "~> 2.0", only: :dev, runtime: false}
    ]

  defp description() do
    """
    A wrapper for `Application.get_config/3` and `System.get_env/1` that makes it easy
    to swap in process-specific overrides. Among other things, this allows tests
    to provide async-safe overrides.
    """
  end

  defp dialyzer,
    do: [
      plt_add_apps: [:ex_unit, :mix],
      plt_add_deps: :app_tree,
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]

  defp docs,
    do: [
      extras: extras(),
      source_ref: "v#{@version}",
      main: "overview"
    ]

  defp extras() do
    [
      "pages/overview.md"
    ]
  end

  defp package(),
    do: [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG* src),
      licenses: ["Apache"],
      links: %{"GitHub" => "https://github.com/synchronal/elixir-gestalt"},
      maintainers: ["synchronal.dev", "Eric Saxby"]
    ]
end
