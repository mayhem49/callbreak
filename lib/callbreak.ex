defmodule Callbreak do
  use Application

  alias Callbreak.Game

  @impl true
  def start(_start_type, _start_args) do
    game_id = :my_callbreak
    # game_id = :only_one_game_currently 
    children = [
      {Registry, keys: :unique, name: Callbreak.Registry},
      {Callbreak.Player, {game_id, :p1, :bot}},
      {Callbreak.Player, {game_id, :p2, :bot}},
      {Callbreak.Player, {game_id, :p3, :bot}},
      {Callbreak.Player, {game_id, :p4, :bot}},
      {Callbreak.GameServer, {game_id, [:p1, :p2, :p3, :p4]}}
    ]

    # one for all currently
    # todo separate supervisor for players
    Supervisor.start_link(children, strategy: :one_for_all)
  end

  def service_name(service_id) do
    {:via, Registry, {Callbreak.Registry, service_id}}
  end

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
        {_i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))
        {_i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))
        {_i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))
        {_i, g} = Game.handle_play(g, g.current_player, get_random_card(g, g.current_player))

        g
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
    Enum.random(Map.get(game.current_hand.cards, player))
  end
end
