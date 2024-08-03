defmodule Callbreak.Hand do
  @moduledoc """
  This module keeps track of the hand being played
  """
  alias Callbreak.{AutoPlay, Deck, Trick}

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
  def new do
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
      Deck.distribute(Callbreak.Deck.new(), length(players))

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
  def take_bid(_, _, _), do: {:error, :not_bidding_currently}

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

  def play(_, _, _), do: {:error, :not_playing_currently}

  def maybe_hand_completed(hand) do
    if hand_completed?(hand) do
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
    {:card, AutoPlay.get_playable_card(Map.get(hand.cards, player), hand.current_trick)}
  end

  def bidding_completed?(hand) do
    hand.hand_state == :playing
  end

  # private functions
  defp validate_card_play(hand, player, card) do
    current_cards = Map.get(hand.cards, player)
    card_index = Enum.find_index(current_cards, fn curr_card -> curr_card == card end)

    if card_index do
      playable_cards = AutoPlay.get_playable_cards(current_cards, hand.current_trick)

      if card in playable_cards,
        do: {:ok, card_index},
        else: {:error, {:invalid_play_card, card}}
    else
      {:error, {:non_existent_card, card}}
    end
  end

  defp maybe_find_trick_winner(hand) do
    case hand.current_trick |> Trick.cards() |> Enum.count() do
      4 ->
        {winner, _card} = Trick.winner(hand.current_trick)

        hand = %{
          hand
          | current_trick: Trick.new(),
            tricks: Map.update(hand.tricks, winner, 1, &(&1 + 1))
        }

        {hand, winner}

      _ ->
        {hand, nil}
    end
  end

  defp hand_completed?(hand) do
    # OR check hand.cards is empty or not?
    total_hand = Enum.reduce(hand.tricks, 0, fn {_, trick}, acc -> acc + trick end)
    total_hand == 13
  end
end
