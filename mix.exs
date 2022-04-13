defmodule Djbot.MixProject do
  use Mix.Project

  def project do
    [
      app: :djbot,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Djbot, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, git: "https://github.com/BrandtHill/nostrum.git"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.3"}
    ]
  end
end
