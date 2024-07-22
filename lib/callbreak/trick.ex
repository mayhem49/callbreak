defmodule Callbreak.Trick do
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

  def play(%{start_suit: nil} = trick, player, card) do
    {_rank, suit} = card

    %{trick | start_suit: suit}
    |> play(player, card)
  end

  def play(trick, player, card) do
    %{trick | cards: Map.put(trick.cards, player, card)}
  end

  def start_suit(%{start_suit: start_suit}), do: start_suit
end
