defmodule Naive.Trader do
  use GenServer, restart: :temporary

  require Logger

  alias Decimal, as: D
  alias Streamer.Binance.TradeEvent

  @binance_client Application.get_env(:naive, :binance_client)

  defmodule State do
    @enforce_keys ~w(
      id
      symbol
      budget
      buy_down_interval
      profit_interval
      rebuy_interval
      rebuy_notified
      tick_size
      step_size
    )a
    defstruct ~w(
      id
      symbol
      budget
      buy_down_interval
      buy_order
      sell_order
      profit_interval
      rebuy_interval
      rebuy_notified
      tick_size
      step_size
    )a
  end

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(%State{id: id, symbol: symbol} = state) do
    symbol = String.upcase(symbol)
    Logger.info("Initializing new trader(#{id}) for symbol(#{symbol})")

    Phoenix.PubSub.subscribe(
      Streamer.PubSub,
      "trade_events:#{symbol}"
    )

    {:ok, state}
  end

  # State 1 - New trader places order
  def handle_info(
        %TradeEvent{price: price},
        %State{
          id: id,
          symbol: symbol,
          budget: budget,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          step_size: step_size
        } = state
      ) do
    price = calculate_buy_price(price, buy_down_interval, tick_size)
    quantity = calculate_quantity(budget, price, step_size)

    Logger.info(
      "The trader(#{id}) is placing a BUY order " <>
        "for #{symbol} @ #{price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    new_state = %{state | buy_order: order}
    Naive.Leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # State 2 where order is already filled (ignore)
  def handle_info(
        %Streamer.Binance.TradeEvent{
          buyer_order_id: order_id
        },
        %State{
          buy_order: %Binance.OrderResponse{
            order_id: order_id,
            status: "FILLED"
          },
          sell_order: %Binance.OrderResponse{}
        } = state
      ) do
    {:noreply, state}
  end

  # State 2 - Got buy confirmation, place sell order
  def handle_info(
        %TradeEvent{
          buyer_order_id: order_id
        },
        %State{
          id: id,
          symbol: symbol,
          buy_order:
            %Binance.OrderResponse{
              price: buy_price,
              order_id: order_id,
              orig_qty: quantity,
              transact_time: timestamp
            } = buy_order,
          profit_interval: profit_interval,
          tick_size: tick_size
        } = state
      ) do
    {:ok, %Binance.Order{} = current_buy_order} =
      @binance_client.get_order(
        symbol,
        timestamp,
        order_id
      )

    buy_order = %{buy_order | status: current_buy_order.status}

    {:ok, new_state} =
      if buy_order.status == "FILLED" do
        sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

        Logger.info(
          "The trader(#{id}) is placing a SELL order for " <>
            "#{symbol} @ #{sell_price}, quantity: #{quantity}."
        )

        {:ok, %Binance.OrderResponse{} = order} =
          @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

        {:ok, %{state | buy_order: buy_order, sell_order: order}}
      else
        Logger.info("Trader's(#{id} #{symbol} BUY order got partially filled")
        {:ok, %{state | buy_order: buy_order}}
      end

    Naive.Leader.notify(:trader_state_updated, new_state)
    {:noreply, new_state}
  end

  # State 3 - Sell order was fullfilled
  def handle_info(
        %TradeEvent{
          seller_order_id: order_id
        },
        %State{
          id: id,
          symbol: symbol,
          sell_order:
            %Binance.OrderResponse{
              order_id: order_id,
              transact_time: timestamp
            } = sell_order
        } = state
      ) do
    {:ok, %Binance.Order{} = current_sell_order} =
      @binance_client.get_order(
        symbol,
        timestamp,
        order_id
      )

    sell_order = %{sell_order | status: current_sell_order.status}

    if sell_order.status == "FILLED" do
      Logger.info("Trader(#{id}) finished trade cycle for #{symbol}")
      {:stop, :normal, state}
    else
      Logger.info("Trader's(#{id} #{symbol} SELL order got partially filled")
      new_state = %{state | sell_order: sell_order}
      {:noreply, new_state}
    end
  end

  # Rebuy event
  def handle_info(
        %TradeEvent{
          price: current_price
        },
        %State{
          id: id,
          symbol: symbol,
          buy_order: %Binance.OrderResponse{
            price: buy_price
          },
          rebuy_interval: rebuy_interval,
          rebuy_notified: false
        } = state
      ) do
    if trigger_rebuy?(buy_price, current_price, rebuy_interval) do
      Logger.info("Rebuy triggered for #{symbol} by the trader(#{id})")
      new_state = %{state | rebuy_notified: true}
      Naive.Leader.notify(:rebuy_triggered, new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Ignore all other trade events
  def handle_info(%TradeEvent{}, state) do
    {:noreply, state}
  end

  defp calculate_buy_price(price, buy_down_interval, tick_size) do
    current_price = D.new(price)

    # not necessarily legal price
    exact_buy_price =
      D.sub(
        current_price,
        D.mult(current_price, buy_down_interval)
      )

    D.to_float(
      D.mult(
        D.div_int(exact_buy_price, tick_size),
        tick_size
      )
    )
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    fee = D.new("1.001")
    original_price = D.mult(D.new(buy_price), fee)

    net_target_price =
      D.mult(
        original_price,
        D.add("1.0", profit_interval)
      )

    gross_target_price = D.mult(net_target_price, fee)

    D.to_float(
      D.mult(
        D.div_int(gross_target_price, tick_size),
        tick_size
      )
    )
  end

  defp calculate_quantity(budget, price, step_size) do
    price = D.from_float(price)

    # not necessarily legal quantity
    exact_target_quantity = D.div(budget, price)

    D.to_float(
      D.mult(
        D.div_int(exact_target_quantity, step_size),
        step_size
      )
    )
  end

  defp trigger_rebuy?(buy_price, current_price, rebuy_interval) do
    current_price = D.new(current_price)
    buy_price = D.new(buy_price)

    rebuy_price =
      D.sub(
        buy_price,
        D.mult(buy_price, rebuy_interval)
      )

    D.lt?(current_price, rebuy_price)
  end
end
