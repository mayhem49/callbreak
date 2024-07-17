defmodule Callbreak do
  use Application

  alias Callbreak.Game

  @impl true
  def start(_start_type, _start_args) do
    game_id = :my_callbreak

    children = [
      {Registry, keys: :unique, name: Callbreak.Registry},
      Callbreak.GameDynamicSupervisor
      # {Callbreak.GameSupervisor, {game_id, players}}
    ]

    return_value = Supervisor.start_link(children, strategy: :one_for_all)

    players = [{:p1, :bot}, {:p2, :bot}, {:p3, :bot}, {:p4, :bot}]
    game_id = :my_callbreak
    Callbreak.GameDynamicSupervisor.start_game({game_id, players})
    # players = [{:p5, :bot}, {:p6, :bot}, {:p7, :bot}, {:p8, :bot}]
    # game_id = :my_callbreak_another
    # Callbreak.GameDynamicSupervisor.start_game({game_id, players})

    return_value
  end

  def observe() do
    Mix.ensure_application!(:wx)
    Mix.ensure_application!(:runtime_tools)
    Mix.ensure_application!(:observer)
    :observer.start()
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
