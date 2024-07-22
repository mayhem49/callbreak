defmodule Callbreak.Player do
  alias Callbreak.{GameServer, Card, Application, Deck, Trick}
  require Logger

  # todo maybe store opponents position in liveview since that is only related to rendering?
  defstruct [
    :game_id,
    :player_id,
    :cards,
    :current_trick,
    :opponents,
    :current_hand,
    :scorecard
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
      scorecard: []
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

  def get_opponent(player, position) when position in [:top, :left, :right, :bottom] do
    Enum.find_value(
      player.opponents,
      fn
        {opp, ^position} -> opp
        _ -> nil
      end
    )
  end

  def add_opponents(player, opponents) when is_list(opponents) do
    opponents = Enum.zip(opponents, [:left, :top, :right])
    %{player | opponents: Map.new(opponents)}
  end

  # todo rename
  def set_opponents_final(player, opponents) do
    # todo check game about how is opponents sent must be %{player: position} 
    # or calculated by player
    Logger.warning("opp final #{inspect(opponents)}")
    %{player | opponents: opponents}
  end

  def add_new_opponent(player, new_player) do
    position = [:left, :top, :right]
    count = Enum.count(player.opponents)
    position = Enum.at(position, max(0, count - 1))
    %{player | opponents: Map.put(player.opponents, position, new_player)}
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

    %{player | current_trick: Trick.new(), current_hand: current_hand}
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

  # rendering related
  def current_score_to_string(player, target_player) do
    case Map.get(player.current_hand, target_player) do
      {bid, win} -> "#{win}/#{bid}"
      nil -> ""
    end
  end

  # returns an array with card and postion to iterate to 
  def get_current_trick_cards(player) do
    IO.inspect(player.current_trick.cards, label: :get_current_trick_cards)
    IO.inspect(player.opponents, label: :get_current_trick_cards)

    player.current_trick.cards
    |> Enum.map(fn {card_player, card} ->
      position = Map.get(player.opponents, card_player)
      {position, card}
    end)
    |> IO.inspect(label: :get_current_trick_cards)
  end

  # old
  # old

  # these error shouldn't occur [just in case]
  def handle_cast({error, _card} = _message, state)
      when error in [:invalid_play_card, :non_existent_card] do
    # if state.player_type == :interactive,
    # do: IO.inspect(message, label: "error")

    GenServer.cast(self(), {:play})
    state
  end

  def handle_cast(message, state)
      when message in [
             {:invalid_play_card},
             {:out_of_turn},
             {:not_playing_currently},
             {:not_bidding_currently}
           ] do
    # if state.player_type == :interactive,
    # do: IO.inspect("Error: #{message}")

    state
  end

  def handle_cast({:invalid_bid, _bid}, state) do
    GenServer.cast(self(), {:bid})
    state
  end

  # end of error

  # def handle_cast({:trick_winner, winner}, state),
  # do: %{state | tricks: Map.update(state.tricks, winner, 1, &(&1 + 1)), current_trick: []}

  def handle_cast({:winner, _winner}, state), do: state

  def handle_cast({:game_completed}, state) do
    IO.inspect(:game_completed)
    state
  end

  def handle_cast({:scorecard, scorecard, points}, state) do
    # IO.inspect([scorecard | state.scorecard], label: "scorecard")
    IO.inspect(points, label: "points")
    IO.puts("")
    %{state | scorecard: [scorecard | state.scorecard]}
  end
end

#    <div class="card-play right"  :if={@current_card}>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    </div>
#
#    <div class="card-play left"  :if={@current_card}>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    </div>
#    <div class="card-play top"  :if={@current_card}>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    </div>
#    <div class="card-play bottom"  :if={@current_card}>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    <span><%=Callbreak.Card.card_to_string(@current_card) %></span>
#    </div>
#
