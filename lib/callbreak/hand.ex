defmodule Callbreak.Hand do
  alias Callbreak.{Deck, Card, Trick, AutoPlay}

  @moduledoc """
  This module keeps track of the hand being played
  """

  defstruct [
    # reamining cards of each player
    :cards,
    # tricks played in current hand
    :tricks,
    # should Game track the current_trick? DECIDE
    # ongoing trick
    :current_trick,
    # bidding done by the players
    :bids,
    # dealing -> bidding -> playing 
    :hand_state
  ]

  # cards is the list of player and card
  def new() do
    %__MODULE__{
      cards: %{},
      tricks: %{},
      current_trick: Trick.new(),
      bids: %{},
      hand_state: :dealing
    }
  end

  def deal(%__MODULE__{} = hand, [_, _, _, _] = players) do
    card_chunks =
      Callbreak.Deck.new()
      |> Deck.distribute(length(players))

    cards = Enum.zip(players, card_chunks) |> Map.new()

    hand = %__MODULE__{hand | cards: cards, hand_state: :bidding}
    {hand, cards}
  end

  def take_bid(%{hand_state: :bidding} = hand, player, bid) when bid >= 1 and bid <= 13 do
    bids = Map.put(hand.bids, player, bid)
    hand_state = if Enum.count(bids) == 4, do: :playing, else: hand.hand_state
    {:ok, %{hand | bids: bids, hand_state: hand_state}}
  end

  def take_bid(%{hand_state: :bidding}, _, bid), do: {:error, {:invalid_bid, bid}}
  def take_bid(_, _, _), do: {:error, {:not_bidding_currently}}

  def play(%{hand_state: :playing} = hand, player, play_card) do
    case validate_card_play(hand, player, play_card) do
      {:ok, card_index} ->
        rem_card =
          hand.cards
          |> Map.get(player)
          |> List.delete_at(card_index)

        hand = %{
          hand
          | cards: Map.put(hand.cards, player, rem_card),
            current_trick: Trick.play(hand.current_trick, player, play_card)
        }

        {hand, winner} = maybe_find_trick_winner(hand)
        {:ok, hand, winner}

      {:error, err} ->
        {:error, err}
    end
  end

  def play(_, _, _), do: {:error, {:not_playing_currently}}

  # checks if the `card` player wants to play is valid.
  # It is invalid in following case:
  # = Player donot have that card
  # = Played another suit card despite having card of current suit

  # If valid: {:ok, index}
  # index -> index of card in player's card
  # else: {:error, reason}

  # todo: 
  # see rules about restriction in playing spade if player donot have card of current suit
  # restrict playing smaller cards if bigger cards available
  defp validate_card_play(hand, player, play_card) do
    card_index =
      hand.cards
      |> Map.get(player)
      |> Enum.find_index(fn card -> card == play_card end)

    if card_index do
      curr_suit = Trick.start_suit(hand.current_trick)
      {_play_rank, play_suit} = play_card

      if !curr_suit || play_suit == curr_suit ||
           !contains_card_of_same_suit?(hand, player, curr_suit) do
        {:ok, card_index}
      else
        {:error, {:invalid_play_card, play_card}}
      end
    else
      {:error, {:non_existent_card, play_card}}
    end
  end

  # returns if the player contains card of `suit` suit
  defp contains_card_of_same_suit?(hand, player, suit) do
    hand.cards
    |> Map.get(player)
    |> Enum.any?(fn
      {_, ^suit} -> true
      _ -> false
    end)
  end

  defp maybe_find_trick_winner(hand) do
    if Enum.count(hand.current_trick.cards) == 4 do
      {winner, _card} = Trick.winner(hand.current_trick)

      {%{
         hand
         | current_trick: Trick.new(),
           tricks: Map.update(hand.tricks, winner, 1, &(&1 + 1))
       }, winner}
    else
      {hand, nil}
    end
  end

  def is_bidding_completed?(hand) do
    hand.hand_state == :playing
  end

  def is_hand_completed?(hand) do
    # OR check hand.cards is empty or not?
    total_hand = Enum.reduce(hand.tricks, 0, fn {_, trick}, acc -> acc + trick end)
    total_hand == 13
  end

  def maybe_hand_completed(hand) do
    if is_hand_completed?(hand) do
      Enum.reduce(hand.bids, %{}, fn {player, bid}, acc ->
        trick_won = Map.get(hand.tricks, player, 0)

        score =
          if trick_won >= bid,
            do: {bid, trick_won - bid},
            else: {-bid, 0}

        Map.put(acc, player, score)
      end)
    end
  end

  def auto_play(%{hand_state: :bidding} = _hand, _player) do
    {:bid, 3}
  end

  def auto_play(%{hand_state: :playing} = hand, player) do
    {:card, AutoPlay.get_card(Map.get(hand.cards, player), hand.current_trick)}
  end
end

defmodule Callbreak.AutoPlay do
  alias Callbreak.{Trick, Player, Card}

  def get_card(current_cards, %Trick{} = current_trick) do
    get_playable_cards(current_cards, current_trick)
    |> Enum.random()
  end

  def get_playable_cards(current_cards, %Trick{cards: cards})
      when map_size(cards) == 0 do
    current_cards
  end

  def get_playable_cards(current_cards, current_trick) do
    start_suit = Trick.start_suit(current_trick)
    trump_suit = Player.get_trump_suit()

    grouped_cards = Enum.group_by(current_cards, fn {_, suit} -> suit end)
    current_trick_cards = Enum.map(current_trick.cards, fn {_, card} -> card end)

    trump_suit_played? =
      start_suit != trump_suit and
        Enum.any?(
          current_trick_cards,
          fn {_, suit} -> suit == trump_suit end
        )

    case Map.fetch(grouped_cards, start_suit) do
      {:ok, suit_cards} ->
        if trump_suit_played? do
          suit_cards
        else
          max_suit_card = get_max_card_of_suit(current_trick_cards, start_suit)

          max_cards =
            Enum.filter(suit_cards, fn card ->
              Card.rank_to_value(card) > Card.rank_to_value(max_suit_card)
            end)

          if Enum.empty?(max_cards), do: suit_cards, else: max_cards
        end

      :error ->
        case Map.fetch(grouped_cards, trump_suit) do
          {:ok, trump_cards} ->
            if trump_suit_played? do
              max_trump_card = get_max_card_of_suit(current_trick_cards, trump_suit)

              max_trump_cards =
                Enum.filter(trump_cards, fn card ->
                  Card.rank_to_value(card) > Card.rank_to_value(max_trump_card)
                end)

              if Enum.empty?(max_trump_cards), do: trump_cards, else: max_trump_cards
            else
              trump_cards
            end

          :error ->
            current_cards
        end
    end
  end

  # private functions
  defp get_max_card_of_suit(deck, suit) do
    deck
    |> Enum.filter(fn
      {_, ^suit} -> true
      _ -> false
    end)
    |> Enum.max_by(&Card.rank_to_value/1)
  end
end

# there are four players
# each player is served 13 cards at the start of the game. 
# There are five rounds 
# at each round, players play 13 rounds

# card is dealt
# bidding
# bidding happens turn by turn
# playing
