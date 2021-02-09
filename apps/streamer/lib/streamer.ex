defmodule Streamer do
  @moduledoc """
  Documentation for `Streamer`.
  """
  alias Streamer.DynamicStreamerSupervisor

  defdelegate start_streaming(symbol), to: DynamicStreamerSupervisor
  defdelegate stop_streaming(symbol), to: DynamicStreamerSupervisor

  def symbol_info(symbol) do
    Binance.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> IO.inspect()
  end
end
