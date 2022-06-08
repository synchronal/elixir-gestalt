defmodule Gestalt.MixProject do
  use Mix.Project

  @version "1.0.2"

  def project do
    [
      aliases: aliases(),
      app: :gestalt,
      deps: deps(),
      description: description(),
      dialyzer: dialyzer(),
      docs: [
        extras: extras(),
        source_ref: "v#{@version}",
        main: "overview"
      ],
      elixir: "~> 1.9",
      package: package(),
      preferred_cli_env: [credo: :test, dialyzer: :test],
      source_url: "https://github.com/livinginthepast/elixir-gestalt",
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  defp aliases do
    [
      "hex.publish": [
        "credo",
        "dialyzer --quiet --format short",
        "gestalt.tags.create",
        "gestalt.tags.push",
        "hex.publish"
      ]
    ]
  end

  defp deps do
    [
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mix_audit, "~> 1.0", only: :dev, runtime: false}

    ]
  end

  defp description() do
    """
    A wrapper for `Application.get_config/3` and `System.get_env/1` that makes it easy
    to swap in process-specific overrides. Among other things, this allows tests
    to provide async-safe overrides.
    """
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      plt_add_deps: :app_tree
    ]
  end

  defp extras() do
    [
      "pages/overview.md"
    ]
  end

  defp package() do
    [
      licenses: ["Apache"],
      maintainers: ["Eric Saxby"],
      links: %{"GitHub" => "https://github.com/livinginthepast/elixir-gestalt"}
    ]
  end
end
