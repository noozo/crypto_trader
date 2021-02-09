defmodule Streamer.MixProject do
  use Mix.Project

  def project do
    [
      app: :streamer,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Streamer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:binance, "~> 0.7.1"},
      {:ecto_sql, "~> 3.0"},
      {:ecto_enum, "~> 1.4"},
      {:jason, "~> 1.2"},
      {:phoenix_pubsub, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:websockex, "~> 0.4"},

      {:mix_test_watch, "~> 1.0.2", only: [:dev, :test], runtime: false},
      {:ex_unit_notifier, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5.0-rc.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.11.0", only: [:dev, :test], runtime: false}
    ]
  end
end
