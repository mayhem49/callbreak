defmodule Callbreak.Player do
  use GenServer

  @trump_suit :spade
  alias Callbreak.{GameServer, Card}

  def child_spec({player_id, _} = arg) do
    %{
      id: player_id,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def start_link({player_id, _} = arg) do
    IO.puts("starting_player:#{player_id}")
    GenServer.start_link(__MODULE__, arg, name: Callbreak.via_tuple(player_id))
  end

  def notify(player_id, instruction) do
    GenServer.cast(Callbreak.via_tuple(player_id), instruction)
  end

  def join_game(player_id, game_id) do
    GenServer.call(Callbreak.via_tuple(player_id), {:join_game, game_id})
  end

  @impl true
  def init({player_id, player_type}) do
    {:ok,
     %{
       game_id: nil,
       player_id: player_id,
       player_type: player_type,
       opponents: [],
       dealer: nil,
       cards: [],
       current_trick: [],
       bids: %{},
       tricks: %{},
       scorecard: []
     }}
  end

  @impl true
  def handle_call({:join_game, game_id}, _from, state),
    do: {:reply, :ok, %{state | game_id: game_id}}

  @impl true
  def handle_cast({:dealer, dealer}, state), do: {:noreply, %{state | dealer: dealer}}

  @impl true
  def handle_cast({:cards, cards}, state),
    do: {:noreply, %{state | cards: arrange_cards(cards)}}

  @impl true
  def handle_cast({:play, :self, card}, state),
    do:
      {:noreply,
       %{
         state
         | cards: List.delete(state.cards, card),
           current_trick: [{state.player_id, card} | state.current_trick]
       }}

  @impl true
  def handle_cast({:play, player, card}, state),
    do: {:noreply, %{state | current_trick: [{player, card} | state.current_trick]}}

  @impl true
  def handle_cast({:bid, :self, bid}, state),
    do: {:noreply, %{state | bids: Map.put(state.bids, state.player_id, bid)}}

  @impl true
  def handle_cast({:bid, player, bid}, state),
    do: {:noreply, %{state | bids: Map.put(state.bids, player, bid)}}

  # these error shouldn't occur [just in case]
  @impl true
  def handle_cast({error, _card} = message, state)
      when error in [:invalid_play_card, :non_existent_card] do
    if state.player_type == :interactive,
      do: IO.inspect(message, label: "error")

    GenServer.cast(self(), {:play})
    {:noreply, state}
  end

  @impl true
  def handle_cast(message, state)
      when message in [
             {:invalid_play_card},
             {:out_of_turn},
             {:not_playing_currently},
             {:not_bidding_currently}
           ] do
    if state.player_type == :interactive,
      do: IO.inspect("Error: #{message}")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:invalid_bid, _bid}, state) do
    GenServer.cast(self(), {:bid})
    {:noreply, state}
  end

  # end of error

  @impl true
  def handle_cast({:trick_winner, winner}, state),
    do:
      {:noreply,
       %{state | tricks: Map.update(state.tricks, winner, 1, &(&1 + 1)), current_trick: []}}

  @impl true
  def handle_cast({:winner, _winner}, state), do: {:noreply, state}

  @impl true
  def handle_cast({:game_completed}, state) do
    IO.inspect(:game_completed)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:scorecard, scorecard, points}, state) do
    # IO.inspect([scorecard | state.scorecard], label: "scorecard")
    IO.inspect(points, label: "points")
    IO.puts("")
    {:noreply, %{state | scorecard: [scorecard | state.scorecard]}}
  end

  @impl true
  def handle_cast({:bid}, state) do
    bid =
      case state.player_type do
        :interactive ->
          read_bid(state)

        :bot ->
          bot_bid(state)
          # Board.minmax(state.board, state.symbol)
      end

    GameServer.bid(state.game_id, state.player_id, bid)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:play}, state) do
    play_card =
      case state.player_type do
        :interactive ->
          state
          |> read_play_card()
          |> IO.inspect(label: "your card")

        :bot ->
          bot_play(state)
          # Board.minmax(state.board, state.symbol)
      end

    GameServer.play(state.game_id, state.player_id, play_card)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:opponents, opponents}, state) do
    %{state | opponents: [opponents | state.opponents]}

    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_player, new_player}, state),
    do: {:noreply, %{state | opponents: [new_player | state.opponents]}}

  def read_play_card(state) do
    print_cards(state)

    prompt =
      if state.current_trick == [] do
        "#{state.player_id} play_first_card(2h)"
      else
        print_tricks(state)
        "#{state.player_id} play_card(2h): "
      end

    input = IO.gets(prompt)

    case Card.parse_card(input) do
      {:ok, card} ->
        card

      {:error, err_msg} ->
        IO.inspect(err_msg)
        read_play_card(state)
    end
  end

  def read_bid(state) do
    print_cards(state)

    bid =
      IO.gets("#{state.player_id} bet(1-13): ")
      |> String.trim()
      |> Integer.parse()

    case bid do
      {bid, ""} ->
        bid

      _ ->
        IO.inspect("Invalid bid #{bid}")
        read_bid(state)
    end
  end

  def bot_bid(_state) do
    # for now
    3
  end

  @doc """
  if first_play: play random

  the bot plays as follows:
  if there is card of existing suit: play  the maximum of that suit
  else if there is card of trump_suit: play the minimum of trump suit
  else: play the smallest of remaining two suits
  """
  def bot_play(%{current_trick: [], cards: cards}), do: Enum.random(cards)

  def bot_play(state) do
    {_, {_, curr_suit}} = List.last(state.current_trick)
    grouped_cards = Enum.group_by(state.cards, fn {_, suit} -> suit end)

    # IO.inspect {grouped_cards, curr_suit} , label: :botplay
    case Map.fetch(grouped_cards, curr_suit) do
      {:ok, suit_cards} ->
        Enum.max_by(suit_cards, &Card.rank_to_value/1)

      :error ->
        case Map.fetch(grouped_cards, @trump_suit) do
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

  defp print_tricks(state) do
    IO.puts("current round:")

    state.current_trick
    |> Enum.reverse()
    |> Enum.each(fn {_player, card} ->
      card
      |> Card.card_to_string()
      |> IO.write()

      IO.write(" ")
    end)

    IO.puts("")
  end

  defp print_cards(state) do
    IO.inspect("your cards: ")

    Enum.each(state.cards, fn card ->
      card
      |> Card.card_to_string()
      |> IO.write()

      IO.write(" ")
    end)

    IO.puts("")
  end

  defp arrange_cards(cards) do
    cards
    |> Enum.group_by(fn {_, suit} -> suit end)
    |> Enum.flat_map(fn {_suit, card} ->
      Enum.sort(card, {:desc, Card})
    end)
  end
end
