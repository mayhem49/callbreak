defmodule Callbreak.Player.Bot do
  use GenServer
  alias Callbreak.{Application, GameServer, Player, Card, Trick}

  require Logger

  def start_link({player_id, game_id} = init_arg) do
    Logger.info("Bot Player started #{player_id} #{game_id}")
    GenServer.start_link(__MODULE__, init_arg, name: Application.via_tuple(player_id))
  end

  @impl true
  def init({player_id, game_id}) do
    {:ok, Player.new(player_id, game_id)}
  end

  # final
  @impl true
  def handle_cast({:new_player, new_player} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.add_new_opponent(state, new_player)}
  end

  def handle_cast({:opponents, opponents} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.add_opponents(state, opponents)}
  end

  def handle_cast({:game_start, opponents} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.set_opponents_final(state, opponents)}
  end

  def handle_cast({:cards, _dealer, _curr_player, cards} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.set_cards(state, cards)}
  end

  @impl true
  def handle_cast(:bid = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    bid = bot_bid(state)
    GameServer.bid(state.game_id, state.player_id, bid)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:bid, bidder, bid} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.set_bid(state, bidder, bid)}
  end

  def handle_cast(:play = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")
    play_card = bot_play(state)
    GameServer.play(state.game_id, state.player_id, play_card)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:play, player, card} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")
    {:noreply, Player.handle_play(state, player, card)}
  end

  def handle_cast({:trick_winner, winner} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")
    {:noreply, Player.handle_trick_completion(state, winner)}
  end

  def handle_cast(msg, state) do
    Logger.warning("UNHANDLED MESSAGE #{inspect(state.player_id)}  #{inspect(msg)}")
    {:noreply, state}
  end

  # utilities
  # for now
  def bot_bid(_state) do
    3
  end

  @doc """
  if first_play: play random

  the bot plays as follows:
  if there is card of existing suit: play  the maximum of that suit
  else if there is card of trump_suit: play the minimum of trump suit
  else: play the smallest of remaining two suits
  """
  def bot_play(%{current_trick: current_trick, cards: cards})
      when map_size(current_trick) == 0 do
    Enum.random(cards)
  end

  def bot_play(state) do
    start_suit = Trick.start_suit(state.current_trick)
    grouped_cards = Enum.group_by(state.cards, fn {_, suit} -> suit end)

    # IO.inspect {grouped_cards, start_suit} , label: :botplay
    case Map.fetch(grouped_cards, start_suit) do
      {:ok, suit_cards} ->
        Enum.max_by(suit_cards, &Card.rank_to_value/1)

      :error ->
        case Map.fetch(grouped_cards, Player.get_trump_suit()) do
          {:ok, trump_cards} ->
            Enum.min_by(trump_cards, &Card.rank_to_value/1)

          :error ->
            Enum.min_by(state.cards, &Card.rank_to_value/1)
            # todo: bot improvement
            # play whichever have more no of cards
            # also factor in the cards played
        end
    end
  end
end

# currently some messages are required to be sent by game server to handle the ui change
# but are not necessaary for the bot
# may be usig pubsub, that can be made more efficient
