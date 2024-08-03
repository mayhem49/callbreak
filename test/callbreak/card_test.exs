defmodule CardTest do
  use ExUnit.Case
  alias Callbreak.Card

  test "parses the cards correctly" do
    tests = [
      {"as", {:ace, :spade}},
      {"kc", {:king, :club}},
      {"qd", {:queen, :diamond}},
      {"jh", {:jack, :heart}},
      {"2c", {2, :club}},
      {"3d", {3, :diamond}},
      {"4h", {4, :heart}},
      {"5s", {5, :spade}},
      {"6c", {6, :club}},
      {"7d", {7, :diamond}},
      {"8h", {8, :heart}},
      {"9d", {9, :diamond}},
      {"10h", {10, :heart}},
      {"  10h", {10, :heart}},
      {"10h  ", {10, :heart}},
      {"  10h  ", {10, :heart}},
      {"  10 h  ", {10, :heart}},
      {"  10   h  ", {10, :heart}}
    ]

    Enum.each(tests, fn {string, card} ->
      assert {:ok, card} == Card.parse_card(string)
    end)
  end

  test "convert card to string string correctly" do
    tests = [
      {{:ace, :spade}, "A♠"},
      {{:king, :club}, "K♣"},
      {{:queen, :diamond}, "Q♦"},
      {{:jack, :heart}, "J♥"},
      {{2, :club}, "2♣"},
      {{3, :diamond}, "3♦"},
      {{4, :heart}, "4♥"},
      {{5, :spade}, "5♠"},
      {{6, :club}, "6♣"},
      {{7, :diamond}, "7♦"},
      {{8, :heart}, "8♥"},
      {{9, :diamond}, "9♦"},
      {{10, :heart}, "10♥"}
    ]

    Enum.each(tests, fn {card, string} ->
      assert string == Card.card_to_string(card)
    end)
  end

  test "compare two cards of same suit correctly" do
    c1 = {2, :spade}
    c2 = {10, :spade}
    c3 = {:ace, :spade}

    assert Card.compare(c1, c1) == :eq
    assert Card.compare(c1, c2) == :lt
    assert Card.compare(c2, c1) == :gt

    assert Card.compare(c3, c3) == :eq
    assert Card.compare(c2, c3) == :lt
    assert Card.compare(c3, c2) == :gt
  end

  test "converts rank to value correctly" do
    tests = [
      {:ace, 14},
      {:king, 13},
      {:queen, 12},
      {:jack, 11}
    ]

    # test face cards
    Enum.each(tests, fn {rank, value} ->
      assert value == Card.rank_to_value({rank, :spade})
    end)

    # test valid rank cards
    Enum.each(2..10, fn rank ->
      assert rank == Card.rank_to_value({rank, :heart})
    end)

    # test invalid ranks
    # Enum.random(11..10000, fn rank ->
    # assertRaise
    # end)
  end
end
