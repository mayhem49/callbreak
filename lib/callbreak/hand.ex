defmodule Callbreak.Hand do
  alias Callbreak.Deck

  @moduledoc """
  This module keeps track of the hand being played
  """

  @trump_suit :spade
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
      current_trick: [],
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
            current_trick: [{player, play_card} | hand.current_trick]
        }

        {hand, winner} = maybe_find_trick_winner(hand)
        {:ok, hand, winner}

      {:error, err} ->
        {:error, err}
    end
  end

  def play(_, _, _), do: {:error, {:not_playing_currently}}

  @doc """
  checks if the `card` player wants to play is valid.
  It is invalid in following case:
  = Player donot have that card
  = Played another suit card despite having card of current suit

  If valid: {:ok, index}
  index -> index of card in player's card
  else: {:error, reason}

  todo: 
  see rules about restriction in playing spade if player donot have card of current suit
  restrict playing smaller cards if bigger cards available
  """
  defp validate_card_play(hand, player, play_card) do
    card_index =
      hand.cards
      |> Map.get(player)
      |> Enum.find_index(fn card -> card == play_card end)

    if card_index do
      curr_suit = current_suit(hand)
      {play_rank, play_suit} = play_card

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

  @doc """
  returns the current suit if exists
  """
  defp current_suit(hand) do
    case List.last(hand.current_trick) do
      nil -> nil
      {_, {_, suit}} -> suit
    end
  end

  @doc """
  returns if the player contains card of `suit` suit
  """
  defp contains_card_of_same_suit?(hand, player, suit) do
    hand.cards
    |> Map.get(player)
    |> Enum.any?(fn
      {_, ^suit} -> true
      _ -> false
    end)
  end

  defp maybe_find_trick_winner(hand) do
    if Enum.count(hand.current_trick) == 4 do
      {winner, _card} =
        hand.current_trick
        |> Enum.reverse()
        |> Enum.reduce(fn
          {_, {curr_rank, suit}} = current, {_, {winner_rank, suit}} = winner ->
            if Deck.rank_gt?(curr_rank, winner_rank),
              do: current,
              else: winner

          {_, {_, @trump_suit}} = current, _ ->
            current

          _, winner ->
            winner
        end)

      {%{hand | current_trick: [], tricks: Map.update(hand.tricks, winner, 1, &(&1 + 1))}, winner}
      # {%{hand | current_trick: [], tricks: [hand.current_trick  | hand.tricks ]}, winner_card}
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
          if trick_won > bid,
            do: {bid, trick_won - bid},
            else: {-bid, 0}

        Map.put(acc, player, score)
      end)
    end
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
