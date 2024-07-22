defmodule GameTest do
  use ExUnit.Case
  alias Callbreak.{Game, Card, Deck}
  # tods: test instructions also
  test "game is started correctly" do
    {_i, _g} = Game.new({:my_random_game, [:mp1, :mp2, :mp3, :mp4]})
  end

  test "can only bid in one's turn" do
    {i, g} = Game.new({:my_random_game, [:mp1, :mp2, :mp3, :mp4]})
    curr_player = g.current_player

    # bidding in turn
    {i, g} = Game.handle_bid(g, curr_player, 3)
    assert Enum.member?(i, instruction(curr_player, {:bid, :self, 3}))

    # bidding out of turn
    {i, g} = Game.handle_bid(g, curr_player, 3)
    assert Enum.member?(i, instruction(curr_player, {:out_of_turn}))

    # bidding out of turn
    another_player =
      Enum.find(g.players, fn
        player -> player != g.current_player
      end)

    {i, g} = Game.handle_bid(g, another_player, 3)
    assert Enum.member?(i, instruction(another_player, {:out_of_turn}))
  end

  test "can only play in one's turn" do
    {i, g} = Game.new({:my_random_game, [:mp1, :mp2, :mp3, :mp4]})

    # complete bidding
    g = complete_bidding(g)

    curr_player = g.current_player

    # playing in turn
    {i, g} = Game.handle_play(g, g.current_player, get_random_card_of_player(g, g.current_player))
    assert false == Enum.member?(i, instruction(g.current_player, {:out_of_turn}))

    # playing out of turn
    {i, g} = Game.handle_play(g, curr_player, get_random_card_of_player(g, curr_player))
    assert Enum.member?(i, instruction(curr_player, {:out_of_turn}))

    # bidding out of turn
    another_player =
      Enum.find(g.players, fn
        player -> player != g.current_player
      end)

    {i, _g} = Game.handle_play(g, another_player, get_random_card_of_player(g, another_player))
    assert Enum.member?(i, instruction(another_player, {:out_of_turn}))
  end

  defp instruction(player, notification),
    do: {:notify_player, player, notification}

  defp get_random_card_of_player(game, player) do
    Map.get(game.current_hand.cards, player)
    |> Enum.random()
  end

  defp complete_bidding(g) do
    {_i, g} = Game.handle_bid(g, g.current_player, 3)
    {_i, g} = Game.handle_bid(g, g.current_player, 3)
    {_i, g} = Game.handle_bid(g, g.current_player, 3)
    {_i, g} = Game.handle_bid(g, g.current_player, 3)
    g
  end
end
