defmodule GameTest do
  use ExUnit.Case
  alias Callbreak.{Card, Deck}
  alias Callbreak.GameNew, as: Game
  # tods: test instructions also
  @players [:mp1, :mp2, :mp3, :mp4]
  setup do
    game = Game.new(:my_random_game)
    [game: game]
  end

  test "four and only four players can join the game", context do
    game = context[:game]

    game =
      Enum.reduce(@players, game, fn player, game ->
        assert {_i, game} = Game.join_game(game, player)
        game
      end)

    # game moves to running state after 4 players join the game
    assert :running == game.game_state

    # fifth player cannot join game
    player = :some_random_player
    {i, _g} = Game.join_game(game, player)
    assert contains_message?(i, {:error, :game_already_started})
  end

  test "appropriate messages are received after four players join the game", context do
    game = context[:game]
    {_i, game} = Game.join_game(game, :mp1)
    {_i, game} = Game.join_game(game, :mp2)
    {_i, game} = Game.join_game(game, :mp3)
    {i, game} = Game.join_game(game, :mp4)

    # assert contains_message?(i, :game_start)

    assert contains_message_exact?(i, :game_start, 4)
    assert contains_message_exact?(i, :hand_start, 4)
    assert contains_message_exact?(i, :bid, 1)
  end

  test "can only bid in one's turn" do
    {i, g} = new_game({:my_random_game, [:mp1, :mp2, :mp3, :mp4]})
    curr_player = g.current_player

    # bidding in turn
    {i, g} = Game.make_bid(g, curr_player, 3)
    assert Enum.member?(i, instruction(curr_player, {:bid, curr_player, 3}))

    # bidding out of turn
    # {i, g} = Game.make_bid(g, curr_player, 4)
    {i, g} = Game.make_bid(g, curr_player, 4)
    assert Enum.member?(i, instruction(curr_player, {:error, :out_of_turn}))

    # bidding out of turn
    another_player =
      Enum.find(g.players, fn
        player -> player != g.current_player
      end)

    {i, g} = Game.make_bid(g, another_player, 3)
    assert Enum.member?(i, instruction(another_player, {:error, :out_of_turn}))
  end

  test "cannot bid after hand play is started" do
    {_, g} = new_game()
    {i, g} = Game.make_bid(g, g.current_player, 3)
    {i, g} = Game.make_bid(g, g.current_player, 4)
    {i, g} = Game.make_bid(g, g.current_player, 3)
    {i, g} = Game.make_bid(g, g.current_player, 4)
    {i, g} = Game.make_bid(g, g.current_player, 4)
    assert contains_message?(i, {:error, :not_bidding_currently})
  end

  test "appropriate messages are received after four players bid" do
    {i, g} = new_game()
    # complete bidding
    {i, g} = complete_bidding(g)
    assert contains_message?(i, :hand_play_start)
    assert contains_message?(i, :play)
  end

  test "can only play in one's turn" do
    {i, g} = new_game({:my_random_game, [:mp1, :mp2, :mp3, :mp4]})

    # complete bidding
    {_i, g} = complete_bidding(g)

    curr_player = g.current_player

    # playing in turn
    {i, g} = Game.play_card(g, g.current_player, get_random_card_of_player(g, g.current_player))
    assert false == Enum.member?(i, instruction(g.current_player, {:error, :out_of_turn}))

    # playing out of turn
    {i, g} = Game.play_card(g, curr_player, get_random_card_of_player(g, curr_player))
    assert Enum.member?(i, instruction(curr_player, {:error, :out_of_turn}))

    # bidding out of turn
    another_player =
      Enum.find(g.players, fn
        player -> player != g.current_player
      end)

    {i, _g} = Game.play_card(g, another_player, get_random_card_of_player(g, another_player))
    assert Enum.member?(i, instruction(another_player, {:error, :out_of_turn}))
  end

  defp instruction(player, notification),
    do: {:notify_player, player, notification}

  defp get_random_card_of_player(game, player) do
    Map.get(game.current_hand.cards, player)
    |> Enum.random()
  end

  defp contains_message_exact?(instructions, check_message, check_count) do
    count =
      Enum.count(instructions, fn {_, _, message} ->
        message == check_message
      end)

    count == check_count
  end

  defp contains_message?(instructions, check_message) do
    Enum.any?(instructions, fn {_, _, message} ->
      message == check_message
    end)
  end

  defp new_game() do
    new_game({:my_random_game, @players})
  end

  defp new_game({game_id, players}) do
    game = Game.new(game_id)

    Enum.reduce(players, {nil, game}, fn player, {_, game} ->
      Game.join_game(game, player)
    end)
  end

  defp complete_bidding(g) do
    {_i, g} = Game.make_bid(g, g.current_player, 3)
    {_i, g} = Game.make_bid(g, g.current_player, 3)
    {_i, g} = Game.make_bid(g, g.current_player, 3)
    Game.make_bid(g, g.current_player, 3)
  end
end
