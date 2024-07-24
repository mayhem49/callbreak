defmodule Callbreak.Player do
  alias Callbreak.{GameServer, Card, Application, Deck, Trick}

  # todo maybe store opponents position in liveview since that is only related to rendering?
  defstruct [
    :game_id,
    :player_id,
    :cards,
    :current_trick,
    :opponents,
    :current_hand,
    # total scorecard of all hands played till now
    :scorecard,
    # stores score of each hand in a list
    :hand_scores
  ]

  @trump_suit :spade
  @player_id_len 5

  def new(player_id, game_id) do
    %__MODULE__{
      game_id: game_id,
      player_id: player_id,
      opponents: %{},
      cards: [],
      current_trick: Trick.new(),
      current_hand: %{},
      scorecard: nil,
      hand_scores: []
    }
  end

  def get_player_id_len(), do: @player_id_len
  def get_trump_suit(), do: @trump_suit

  def random_player_id() do
    id =
      Enum.map(1..@player_id_len, fn _ -> Enum.random(?a..?z) end)
      |> List.to_string()

    "player-" <> id
  end

  def notify_liveview(player_id, instruction) do
    [{pid, _}] = Registry.lookup(Callbreak.Registry, player_id)
    GenServer.cast(pid, instruction)
  end

  def register(player_id, player_pid) do
    Application.register(player_id, player_pid)
  end

  def add_opponents(player, opponents) when is_list(opponents) do
    opponents = Enum.zip(opponents, [:left, :top, :right])
    %{player | opponents: Map.new(opponents)}
  end

  # todo rename
  def set_opponents_final(player, opponents) do
    %{player | opponents: opponents}
  end

  def add_new_opponent(player, new_player) do
    position = [:left, :top, :right]
    count = Enum.count(player.opponents)
    position = Enum.at(position, max(0, count - 1))
    %{player | opponents: Map.put(player.opponents, new_player, position)}
  end

  def set_cards(player, cards) do
    %{player | cards: Deck.arrange_cards(cards)}
  end

  def set_bid(player, bidder, bid) do
    %{player | current_hand: Map.put(player.current_hand, bidder, {bid, 0})}
  end

  def handle_trick_completion(player, trick_winner) do
    current_hand =
      Map.update!(player.current_hand, trick_winner, fn {bid, won} -> {bid, won + 1} end)

    %{player | current_hand: %{}, current_trick: Trick.new(), current_hand: current_hand}
  end

  def handle_self_play(state, card) do
    %{
      state
      | cards: List.delete(state.cards, card),
        current_trick: Trick.play(state.current_trick, state.player_id, card)
    }
  end

  def handle_play(%{player_id: player} = state, player, card) do
    handle_self_play(state, card)
  end

  def handle_play(state, player, card) do
    %{
      state
      | current_trick: Trick.play(state.current_trick, player, card)
    }
  end

  def handle_scorecard(player, hand_score, scorecard) do
    # points is the points of last completed hand
    %{player | hand_scores: [hand_score | player.hand_scores], scorecard: scorecard}
  end

  def get_next_turn(%{player_id: current_player} = player, current_player) do
    get_player_at_pos(player, :left)
  end

  def get_next_turn(player, current_player) do
    curr_pos =
      Enum.find_value(player.opponents, fn
        {^current_player, pos} -> pos
        _ -> false
      end)

    next_pos =
      case curr_pos do
        :left -> :top
        :top -> :right
        :right -> :bottom
      end

    get_player_at_pos(player, next_pos)
  end

  def get_player_at_pos(player, :bottom) do
    player.player_id
  end

  def get_player_at_pos(player, pos) do
    Enum.find_value(
      player.opponents,
      fn
        {opp, ^pos} -> opp
        _ -> false
      end
    )
  end
end

defmodule Callbreak.Player.Render do
  @moduledoc """
  transform player data appropriate for rendering
  """

  alias Callbreak.Player
  alias Callbreak.Trick
  alias Callbreak.Card

  def current_score_to_string(player, target_player) do
    case Map.get(player.current_hand, target_player) do
      {bid, win} -> "#{win}/#{bid}"
      nil -> ""
    end
  end

  # returns an array with card and postion to iterate to 
  def get_current_trick_cards(player) do
    player.current_trick.cards
    |> Enum.map(fn
      {card_player, card} ->
        position = Map.get(player.opponents, card_player) || :bottom

        {position, card}
    end)
  end

  def get_cards(%Player{} = player) do
    start_suit = Trick.start_suit(player.current_trick)

    # can play any card if no card available for current suit
    # todo must playt trump if no one else have
    has_card_of_start_suit? =
      start_suit != nil and
        Enum.any?(
          player.cards,
          fn
            {_rank, ^start_suit} -> true
            _ -> false
          end
        )

    player.cards
    |> Enum.with_index()
    |> Enum.map(fn {{_rank, suit} = card, index} ->
      can_play? =
        cond do
          has_card_of_start_suit? and suit == start_suit -> true
          has_card_of_start_suit? -> false
          true -> true
        end

      {index, card, can_play?}
    end)
  end

  def get_scorecard(player) do
    player.hand_scores
    |> Enum.map(fn hand_score ->
      [:left, :top, :right]
      |> Enum.map(fn pos ->
        opponent = Player.get_player_at_pos(player, pos)
        {opponent, Map.get(hand_score, opponent)}
      end)
      |> then(fn scores ->
        [Map.get(hand_score, player.player_id) | scores]
      end)
    end)
    |> IO.inspect(lable: :render_scorecard)
  end
end
