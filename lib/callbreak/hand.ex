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
    # bidding or playing or dealing
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
    # todo don't allow random playihng
    # but allow for now to test
    card_index =
      hand.cards
      |> Map.get(player)
      |> Enum.find_index(fn card -> card == play_card end)

    if card_index do
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
    else
      {:error, {:non_existent_card, play_card}}
    end
  end

  def play(_, _, _), do: {:error, {:not_playing_currently}}

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

  # todo: better logic for state change and data structure for player state
  def is_bidding_completed?(hand) do
    hand.hand_state != :bidding and Enum.count(hand.bids) == 4
  end

  def is_hand_completed?(hand) do
    # OR check hand.cards is empty or not?
    total_hand = Enum.reduce(hand.tricks, 0, fn {_, trick}, acc -> acc + trick end)
    total_hand == 13
  end

  def maybe_hand_completed(hand) do
    # todo update about hand completion
    if is_hand_completed?(hand) do
      Enum.reduce(hand.bids, %{}, fn {player, bid}, acc ->
        trick_won = Map.get(hand.tricks, player, 0)

        score =
          if trick_won > bid,
            do: bid + (trick_won - bid) / 10,
            else: -bid

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
