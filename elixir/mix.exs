defmodule Tailscale.MixProject do
  use Mix.Project

  def project do
    [
      app: :tailscale,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      make_cwd: "c_src",
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.7", runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir bindings for Tailscale - embed Tailscale networking in your Elixir applications
    """
  end

  defp package do
    [
      name: "tailscale",
      files: ~w(lib c_src .formatter.exs mix.exs README.md LICENSE),
      licenses: ["BSD-3-Clause"],
      links: %{"GitHub" => "https://github.com/tailscale/libtailscale"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/tailscale/libtailscale"
    ]
  end
end