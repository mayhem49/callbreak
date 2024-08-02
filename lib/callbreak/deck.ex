defmodule Callbreak.Deck do
  @moduledoc false
  use Callbreak.Constants

  def new do
    @suites
    |> Enum.flat_map(fn suit ->
      Enum.map(@ranks, fn rank -> {rank, suit} end)
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

  # group in the order of @suites
  def arrange_cards(cards) do
    grouped_cards = Enum.group_by(cards, fn {_, suit} -> suit end)

    Enum.flat_map(@suites, fn suit ->
      grouped_cards
      |> Map.get(suit, [])
      |> Enum.sort({:desc, Callbreak.Card})
    end)
  end
end
