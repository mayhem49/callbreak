defmodule Callbreak.Deck do
  @suites [:diamond, :heart, :club, :spade]
  @ranks [:ace, 2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king]

  def new() do
    @suites
    |> Enum.flat_map(fn suite ->
      Enum.map(@ranks, fn rank -> {rank, suite} end)
    end)
    |> Enum.shuffle()
  end

  def get_random_cards() do
    Enum.take_random(new(), 13)
  end

  def random() do
    {Enum.random(@ranks), Enum.random(@suites)}
  end

  def take([card | rest]), do: {:ok, card, rest}

  def take([]), do: {:error, :empty_deck}

  @doc """
  distribute a deck of cards into count players randomly
  make sure deck is divided equally into count players. like 2 4 or 13
  """
  def distribute(deck, count) do
    Enum.chunk_every(deck, div(length(deck), count))
  end

  def arrange_cards(cards) do
    cards
    |> Enum.group_by(fn {_, suit} -> suit end)
    |> Enum.flat_map(fn {_suit, card} ->
      Enum.sort(card, {:desc, Callbreak.Card})
    end)
  end
end
