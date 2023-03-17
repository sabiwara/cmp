defmodule Cmp.MixProject do
  use Mix.Project

  @version "0.1.2"
  @github_url "https://github.com/sabiwara/cmp"

  def project do
    [
      app: :cmp,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        docs: :docs,
        "hex.publish": :docs,
        dialyzer: :test,
        "test.unit": :test,
        "test.prop": :test
      ],
      dialyzer: [flags: [:missing_return, :extra_return]],
      aliases: aliases(),
      consolidate_protocols: Mix.env() != :test,

      # hex
      description: "Semantic comparison and sorting for Elixir",
      package: package(),
      name: "Cmp",
      docs: docs()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      # Optional dependencies
      {:decimal, "~> 2.0", optional: true},
      # doc, benchs
      {:ex_doc, "~> 0.28", only: :docs, runtime: false},
      {:benchee, "~> 1.1", only: :bench, runtime: false},
      # CI
      {:dialyxir, "~> 1.0", only: :test, runtime: false},
      {:stream_data, "~> 0.5.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["sabiwara"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url},
      files: ~w(lib mix.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp aliases do
    [
      "test.unit": ["test --exclude property:true"],
      "test.prop": ["test --only property:true"]
    ]
  end

  defp docs do
    [
      main: "Cmp",
      source_ref: "v#{@version}",
      source_url: @github_url,
      homepage_url: @github_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"]
    ]
  end
end
