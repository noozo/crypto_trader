defmodule Streamer do
  @moduledoc """
  Documentation for `Streamer`.
  """
  def start_streaming(symbol) do
    Streamer.Binance.start_link(symbol)
  end

  def symbol_info(symbol) do
    Binance.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> IO.inspect()
  end
end
