# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :logger,
  level: :info

config :naive, Naive.Repo, url: "postgres://postgres:postgres@127.0.0.1:5433/naive"

config :naive,
  ecto_repos: [Naive.Repo],
  binance_client: BinanceMock,
  trading: %{
    defaults: %{
      chunks: 5,
      budget: 100.0,
      buy_down_interval: 0.0001,
      profit_interval: -0.0012,
      rebuy_interval: 0.001
    }
  }

config :streamer, Streamer.Repo, url: "postgres://postgres:postgres@127.0.0.1:5433/streamer"

config :streamer,
  ecto_repos: [Streamer.Repo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
