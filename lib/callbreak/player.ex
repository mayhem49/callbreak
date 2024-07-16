defmodule Callbreak.Player do
  use GenServer

  @trump_suit :spade
  alias Callbreak.{GameServer}

  def notify(player_id, instruction) do
    GenServer.cast(Callbrak.service_name(player_id), instruction)
  end

  # Callbrak.GameServer.start_game :game, :p1, :p2

  def child_spec({_, player_id, _, _} = arg) do
    %{
      id: player_id,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def start_link({game_id, player_id, player_type, symbol}) do
    IO.puts("player.start_link #{player_id}")

    GenServer.start_link(__MODULE__, {game_id, player_id, player_type, symbol},
      name: Callbrak.service_name(player_id)
    )
  end

  @impl true
  def init({game_id, player_id, player_type, symbol}) when symbol in [:o, :x] do
    {:ok,
     %{
       game_id: game_id,
       player_id: player_id,
       player_type: player_type,
       opponents: [],
       dealer: nil,
       cards: [],
       current_trick: [],
       bids: %{},
       tricks: %{}
     }}
  end

  @impl true
  def handle_cast({:dealer, dealer}, state), do: {:noreply, %{state | dealer: dealer}}

  @impl true
  def handle_cast({:cards, cards}, state), do: {:noreply, %{state | cards: cards}}

  # maybe merge play_success and play?
  # todo: remove from state.cards
  @impl true
  def handle_cast({:play_success, card}, state),
    do: {:noreply, %{state | current_trick: [{state.player_id, card} | state.current_trick]}}

  @impl true
  def handle_cast({:play, player_card}, state),
    do: {:noreply, %{state | current_trick: [player_card | state.current_trick]}}

  # maybe merge bid_success and bid?
  @impl true
  def handle_cast({:bid_success, bid}, state),
    do: {:noreply, %{state | bids: Map.put(state.bids, state.player_id, bid)}}

  @impl true
  def handle_cast({:bid, player, bid}, state),
    do: {:noreply, %{state | bids: Map.put(state.bids, player, bid)}}

  @impl true
  def handle_cast({:trick_winner, winner}, state),
    do:
      {:noreply,
       %{state | tricks: Map.update(state.tricks, winner, 1, &(&1 + 1)), current_trick: []}}

  @impl true
  def handle_cast({:winner, winner}, state), do: {:noreply, state}

  @impl true
  def handle_cast({:game_completed, winner}, state), do: {:noreply, state}

  @impl true
  def handle_cast({:bid}, state) do
    # print_message(state, "opponents", opponents)
    bid =
      case state.player_type do
        :interactive ->
          read_bid(state)

        :bot ->
          bot_bid(state)
          # Board.minmax(state.board, state.symbol)
      end

    GameServer.bid(state.game_id, state.player_id, bid)

    {:noreply, %{state | bid: bid}}
  end

  @impl true
  def handle_cast({:play}, state) do
    # print_message(state, "opponents", opponents)
    bid =
      case state.player_type do
        :interactive ->
          read_play_card(state)

        :bot ->
          bot_play(state)
          # Board.minmax(state.board, state.symbol)
      end

    GameServer.bid(state.game_id, state.player_id, bid)
    {:noreply, %{state | bid: bid}}
  end

  def read_play_card(state) do
    input = IO.gets("#{state.player_id} play_card(2h): ")

    case Deck.parse_card(input) do
      {:ok, card} ->
        card

      {:error, err_msg} ->
        IO.inspect(err_msg)
        read_play_card(state)
    end
  end

  def read_bid(state) do
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

  def bot_bid(state) do
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
  def bot_play(%{tricks: [], cards: cards}), do: Enum.random(cards)

  def bot_play(state) do
    {_, curr_suit} = List.last(state.cards)
    grouped_cards = Enum.group_by(state.cards, fn {_, suit} -> suit end)

    case Map.fetch(grouped_cards, curr_suit) do
      {:ok, suit_cards} ->
        Enum.max_by(suit_cards, &Deck.rank_to_value/1)

      :error ->
        case Map.fetch(grouped_cards, @trump_suit) do
          {:ok, trump_cards} ->
            Enum.min_by(trump_cards, &Deck.rank_to_value/1)

          :error ->
            Enum.min_by(state.cards, &Deck.rank_to_value/1)
            # todo: play whichever have more no of cards
            # also factor in the cards played
        end
    end
  end

  @impl true
  def handle_cast({:opponents, opponents}, state) do
    # print_message(state, "opponents", opponents)
    %{state | opponents: opponents}

    {:noreply, state}
  end

  defp read_move(state) do
    IO.gets("#{state.player_id} move(x,y): ")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer(&1))
    |> List.to_tuple()
  end

  defp print_message(state, message) do
    IO.puts("#{state.player_id}: #{message}")
  end

  defp alternate_symbol(:o), do: :x
  defp alternate_symbol(:x), do: :o
end
