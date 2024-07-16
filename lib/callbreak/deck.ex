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

  def take([card | rest]), do: {:ok, card, rest}

  def take([]), do: {:error, :empty_deck}

  @doc """
  distribute a deck of cards into count players randomly
  make sure deck is divided equally into count players. like 2 4 or 13
  """
  def distribute(deck, count) do
    Enum.chunk_every(deck, div(length(deck), count))
  end

  # alternatives for > operator (rank1 > rank2)?
  # only compares rank
  # in case of samke rank and same suit, returns false
  def rank_gt?(rank1, rank2) do
    case {rank1, rank2} do
      {:ace, rank} when rank == :ace ->
        false

      {:ace, _} ->
        true

      {:king, rank} when rank in [:ace, :king] ->
        false

      {:king, _} ->
        true

      {:queen, rank} when rank in [:ace, :king, :queen] ->
        false

      {:queen, _} ->
        true

      {:jack, rank} when rank in [:ace, :king, :queen, :jack] ->
        false

      {:jack, _} ->
        true

      {r1, r2} ->
        r1 > r2
    end
  end

  @doc """
  this function compares rank of two card having same suits only
  """
  def compare({suit, rank1}, {suit, rank2}) do
    case {rank1, rank2} do
      # this is not possible if both cards are from single deck
      {rank, rank} ->
        :eq

      {:ace, _} ->
        :gt

      {:king, :ace} ->
        :lt

      {:king, _} ->
        :gt

      {:queen, rank} when rank in [:ace, :king] ->
        :lt

      {:queen, _} ->
        :gt

      {:jack, rank} when rank in [:ace, :king, :queen] ->
        :lt

      {:jack, _} ->
        :gt

      {r1, r2} ->
        if r1 > r2,
          do: :gt,
          else: :lt
    end
  end

  def parse_card(string) do
    [rank, suit] =
      string
      |> String.trim()
      |> String.split("")

    with {:ok, rank} <- parse_rank(rank),
         {:ok, suit} <- parse_suit(suit) do
      {rank, suit}
    else
      error -> error
    end
  end

  def parse_rank(rank) do
    case rank do
      "a" ->
        {:ok, :ace}

      "k" ->
        {:ok, :king}

      "q" ->
        {:ok, :queen}

      "j" ->
        {:ok, :jack}

      num ->
        case Integer.parse(num) do
          {num, ""} when num >= 2 and num <= 10 ->
            {:ok, num}

          _ ->
            {:error, "Invalid rank: #{num}"}
        end
    end
  end

  def parse_suit(suit) do
    case suit do
      "h" -> {:ok, :heart}
      "s" -> {:ok, :spade}
      "c" -> {:ok, :club}
      "d" -> {:ok, :diamond}
      _ -> {:error, "invalid suti: #{suit}"}
    end
  end

  @doc """
  returns the number for rank to maintain the order:
  :ace, :king, :queen, :jack, 10 , ..., 1
  """
  def rank_to_value({rank, _suit}) do
    case rank do
      :ace -> 20
      :king -> 20
      :queen -> 20
      :jack -> 20
      rank -> rank
    end
  end
end
