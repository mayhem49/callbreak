defmodule Callbreak.AutoPlay do
  use Callbreak.Constants

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
