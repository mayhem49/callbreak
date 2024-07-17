defmodule DeckTest do
  use ExUnit.Case
  alias Callbreak.Deck

  test "parses the cards correctly" do
    tests = [
      {"as", {:ace, :spade}},
      {"kc", {:king, :club}},
      {"qd", {:queen, :diamond}},
      {"jh", {:jack, :heart}},
      {"1s", {1, :spade}},
      {"2c", {2, :club}},
      {"3d", {3, :diamond}},
      {"4h", {4, :heart}},
      {"5s", {5, :spade}},
      {"6c", {6, :club}},
      {"7d", {7, :diamond}},
      {"8h", {8, :heart}},
      {"9d", {9, :diamond}},
      {"10h", {10, :heart}}
      # todo add spaces between and extreme of string
    ]

    Enum.each(tests, fn {string, card} ->
      assert {:ok, card} == Deck.parse_card(string)
    end)
  end
end
