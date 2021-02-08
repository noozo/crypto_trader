defmodule Naive.Trader do
  use GenServer, restart: :temporary

  require Logger

  alias Decimal
  alias Streamer.Binance.TradeEvent

  @binance_client Application.get_env(:naive, :binance_client)

  defmodule State do
    @enforce_keys [:symbol, :profit_interval, :tick_size]
    defstruct ~w(
      symbol
      buy_order
      sell_order
      profit_interval
      tick_size
    )a
  end

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%State{symbol: symbol} = state) do
    symbol = String.upcase(symbol)
    Logger.info("Initializing new trader for symbol(#{symbol})")

    Phoenix.PubSub.subscribe(
      Streamer.PubSub,
      "trade_events:#{symbol}"
    )

    {:ok, state}
  end

  # State 1 - New trader places order
  def handle_info(%TradeEvent{price: price}, %State{symbol: symbol, buy_order: nil} = state) do
    # Hardcoded until chapter 7
    quantity = 100

    Logger.info("Placing BUY order for #{symbol}@#{price}, quantity:#{quantity}")

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    new_state = %{state | buy_order: order}
    Naive.Leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # State 2 - Got buy confirmation, place sell order
  def handle_info(
        %TradeEvent{
          buyer_order_id: order_id,
          quantity: quantity
        },
        %State{
          symbol: symbol,
          buy_order: %Binance.OrderResponse{
            price: buy_price,
            order_id: order_id,
            orig_qty: quantity
          },
          profit_interval: profit_interval,
          tick_size: tick_size
        } = state
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    Logger.info(
      "Buy order filled, placing SELL order for " <>
        "#{symbol}@#{sell_price}), quantity:#{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

    new_state = %{state | sell_order: order}
    Naive.Leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # State 3 - Sell order was fullfilled
  def handle_info(
        %TradeEvent{
          seller_order_id: order_id,
          quantity: quantity
        },
        %State{sell_order: %Binance.OrderResponse{order_id: order_id, orig_qty: quantity}} = state
      ) do
    Logger.info("Trade finished, trader will now exit")

    {:stop, :normal, state}
  end

  # Ignore all other trade events
  def handle_info(%TradeEvent{}, state) do
    {:noreply, state}
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    fee = Decimal.new("1.001")
    original_price = Decimal.mult(Decimal.new(buy_price), fee)

    net_target_price =
      Decimal.mult(
        original_price,
        Decimal.add("1.0", profit_interval)
      )

    gross_target_price = Decimal.mult(net_target_price, fee)

    Decimal.to_float(
      Decimal.mult(
        Decimal.div_int(gross_target_price, tick_size),
        tick_size
      )
    )
  end

  defp fetch_tick_size(symbol) do
    @binance_client.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> Map.get("filters")
    |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
    |> Map.get("tickSize")
    |> Decimal.new()
  end
end
