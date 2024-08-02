defmodule Callbreak.Trick do
  use Callbreak.Constants

  alias Callbreak.Card
  alias Callbreak.Player

  # currently for use by player
  defstruct [
    # suit that is played at first 
    :start_suit,
    :cards,
    :winner
    # winner till now {player, card}
    # :current_winner
  ]

  def new() do
    %__MODULE__{
      start_suit: nil,
      cards: %{},
      winner: nil
      # current_winner: nil
    }
  end

  def play(%__MODULE__{start_suit: nil, winner: nil} = trick, player, card) do
    {_rank, suit} = card

    %{trick | start_suit: suit}
    |> play(player, card)
  end

  def play(%__MODULE__{} = trick, player, card) do
    %{
      trick
      | cards: Map.put(trick.cards, player, card),
        winner: update_winner({player, card}, trick.winner)
    }
  end

  def start_suit(%__MODULE__{start_suit: start_suit}), do: start_suit

  def winner(%__MODULE__{winner: winner}) do
    winner
  end

  # todo: variable renaming
  defp update_winner(new_card_play, nil) do
    new_card_play
  end

  defp update_winner(new_card_play, winner_card_play) do
    trump_suit = Player.get_trump_suit()

    case {new_card_play, winner_card_play} do
      {{_, {_, suit} = curr_card}, {_, {_, suit} = winner_card}} ->
        if Card.compare_same(curr_card, winner_card) == :gt,
          do: new_card_play,
          else: winner_card_play

      {{_, {_, ^trump_suit}} = current, _} ->
        current

      {_, winner} ->
        winner
    end
  end
end
