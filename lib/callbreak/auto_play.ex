defmodule Callbreak.AutoPlay do
  @moduledoc false

  use Callbreak.Constants

  alias Callbreak.{Card, Trick}

  def get_playable_card(current_cards, %Trick{} = current_trick) do
    get_playable_cards(current_cards, current_trick)
    |> Enum.random()
  end

  def get_playable_cards(current_cards, %Trick{cards: cards})
      when map_size(cards) == 0 do
    current_cards
  end

  @doc """
  = get_playable_suit_cards/2
  contains? suit cards ->
  ---- if trump card played? -> all suit cards
  ---- else -> winning suit cards || all suit_cards
  not contains? suit cards -> FALLBACK

  = get_playable_trump_cards/2
  contains? trump cards -> 
  ---- if trump played? -> winning trumps || fallback
  ---- else -> all trump
  not contains? trump cards -> FALLBACK

  @FALLBACK
  all cards


  = improvements
  when trump is played, make playabe cards first half of suit cards?? 

  """
  def get_playable_cards(current_cards, current_trick) do
    grouped_cards = Enum.group_by(current_cards, fn {_, suit} -> suit end)

    with nil <- get_playable_suit_cards(grouped_cards, current_trick),
         nil <- get_playable_trump_cards(grouped_cards, current_trick) do
      current_cards
    else
      playable_cards -> playable_cards
    end
  end

  # private functions
  defp get_playable_suit_cards(grouped_cards, %Trick{} = current_trick) do
    start_suit = Trick.start_suit(current_trick)
    trick_cards = current_trick |> Trick.cards() |> Enum.map(fn {_, card} -> card end)
    trump_suit_played? = Trick.trump_suit_played?(current_trick)

    case Map.get(grouped_cards, start_suit) do
      nil ->
        nil

      suit_cards when trump_suit_played? ->
        suit_cards

      suit_cards ->
        IO.inspect(trick_cards)
        IO.inspect(trick_cards)
        IO.inspect(start_suit)
        IO.inspect(start_suit)
        max_suit_card = get_max_card_of_suit(trick_cards, start_suit)
        greater_cards = get_greater_cards(suit_cards, max_suit_card)
        if Enum.empty?(greater_cards), do: suit_cards, else: greater_cards
    end
  end

  defp get_playable_trump_cards(grouped_cards, %Trick{} = current_trick) do
    trick_cards = current_trick |> Trick.cards() |> Enum.map(fn {_, card} -> card end)
    trump_suit_played? = Trick.trump_suit_played?(current_trick)

    case Map.get(grouped_cards, @trump_suit) do
      nil ->
        nil

      trump_cards when trump_suit_played? ->
        max_trump_card = get_max_card_of_suit(trick_cards, @trump_suit)
        greater_cards = get_greater_cards(trump_cards, max_trump_card)

        if Enum.empty?(greater_cards), do: nil, else: greater_cards

      trump_cards ->
        trump_cards
    end
  end

  defp get_max_card_of_suit(deck, suit) do
    deck
    |> Enum.filter(fn
      {_, ^suit} -> true
      _ -> false
    end)
    |> Enum.max_by(&Card.rank_to_value/1)
  end

  defp get_greater_cards(cards, base_card) do
    Enum.filter(cards, fn card ->
      Card.rank_to_value(card) > Card.rank_to_value(base_card)
    end)
  end
end
