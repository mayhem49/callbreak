defmodule Callbreak.Card do
  @module_doc """
  contains utility functions related to Card.
  There is no data type currently.
  Just use {rank, suit} for card since I have written code like that in all places.
  May change later.
  """

  # guards
  defguardp is_numeric_rank(rank) when rank >= 2 and rank <= 10
  # defguardp is_face_rank(rank) when rank in [:ace, :jack, :queen, :king]
  # defguardp is_rank(rank) when is_numeric_rank(rank) or is_face_rank(rank)

  # public functions
  @doc """
  This function compares rank of two card having same suits only.
  Function to use in Enum functions
  """
  # maybe compare different suit too?
  def compare(c1, c2) do
    rank1 = rank_to_value(c1)
    rank2 = rank_to_value(c2)

    cond do
      rank1 > rank2 -> :gt
      rank1 == rank2 -> :eq
      rank1 < rank2 -> :lt
    end
  end

  @doc """
  compare cards of same suit.

  raises on card of different suits.
  """
  def compare_same({_, suit} = c1, {_, suit} = c2), do: compare(c1, c2)

  @doc """
  This function converts string version of the card. 
  Useful for printing purposes.
  """
  def card_to_string({rank, suit}) do
    rank =
      case rank do
        :ace -> "A"
        :king -> "K"
        :queen -> "Q"
        :jack -> "J"
        rank when is_numeric_rank(rank) -> Integer.to_string(rank)
      end

    suit =
      case suit do
        :heart -> "♥"
        :spade -> "♠"
        :club -> "♣"
        :diamond -> "♦"
      end

    rank <> suit
  end

  @doc """
  builds {rank, suit} from string.
  Can be used for building and testing game from a terminal.
  """
  def parse_card(string) do
    string = String.trim(string)

    with {:ok, rank, rest} <- parse_rank(string),
         {:ok, suit} <- parse_suit(String.trim(rest)) do
      {:ok, {rank, suit}}
    else
      :error -> {:error, "Invalid Card: #{string}"}
    end
  end

  @doc """
  returns the number for rank to maintain the order:
  :ace, :king, :queen, :jack, 10 , ..., 1
  """
  def rank_to_value({rank, _suit}) do
    case rank do
      :ace -> 14
      :king -> 13
      :queen -> 12
      :jack -> 11
      rank when is_numeric_rank(rank) -> rank
    end
  end

  # private functions
  defp parse_rank(rank) do
    case rank do
      "a" <> rest ->
        {:ok, :ace, rest}

      "k" <> rest ->
        {:ok, :king, rest}

      "q" <> rest ->
        {:ok, :queen, rest}

      "j" <> rest ->
        {:ok, :jack, rest}

      rank ->
        case Integer.parse(rank) do
          {num, rest} when is_numeric_rank(num) ->
            {:ok, num, rest}

          :error ->
            :error
        end
    end
  end

  defp parse_suit(suit) do
    case suit do
      "h" -> {:ok, :heart}
      "s" -> {:ok, :spade}
      "c" -> {:ok, :club}
      "d" -> {:ok, :diamond}
      _ -> :error
    end
  end
end
