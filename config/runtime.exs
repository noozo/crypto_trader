# config/runtime.exs
import Config

config :binance,
  api_key: System.fetch_env!("BINANCE_API_KEY"),
  secret_key: System.fetch_env!("BINANCE_API_SECRET")
