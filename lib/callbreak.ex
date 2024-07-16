defmodule Callbreak do
  alias Callbreak.Game

  def new do
    p = [:a, :b, :c, :d]
    {i, g} = Game.new(p)
    IO.inspect(i)

    1..5
    |> Enum.reduce(
      g,
      fn _, g ->
        g
        |> bid()
        |> play()
        |> IO.inspect()
      end
    )

    # bidding
    :ok
  end

  def play(game) do
    IO.inspect("playing")

    1..13
    |> Enum.reduce(
      game,
      fn _, g ->
        {i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))
        {i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))
        {i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))
        {i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))

        IO.inspect(i)
        %{g | instructions: i}
      end
    )
  end

  def bid(game) do
    IO.inspect("bidding")

    1..4
    |> Enum.reduce(
      game,
      fn _, g ->
        IO.inspect(g.current_player, label: "current_player")
        {_i, g} = Game.handle_bid(g, g.current_player, 3)
        g
      end
    )
  end

  def get_random_card(game, player) do
    Enum.random(Map.get(game.current_hand.cards, game.current_player))
  end
end
