defmodule BinanceMock.MixProject do
  use Mix.Project

  def project do
    [
      app: :binance_mock,
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
      mod: {BinanceMock.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:binance, "~> 0.7.1"},
      {:decimal, "~> 2.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:streamer, in_umbrella: true},

      {:mix_test_watch, "~> 1.0.2", only: [:dev, :test], runtime: false},
      {:ex_unit_notifier, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5.0-rc.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.11.0", only: [:dev, :test], runtime: false}
    ]
  end
end
