defmodule Callbreak do
  use Application

  @impl true
  def start(_start_type, _start_args) do
    children = [
      {Registry, keys: :unique, name: Callbreak.Registry},
      Callbreak.GameDynamicSupervisor,
      Callbreak.PlayerSupervisor,
      Callbreak.GameTracker
      # {Callbreak.GameSupervisor, {game_id, players}}
    ]

    return = Supervisor.start_link(children, strategy: :one_for_all)
    new_game()
    return
  end

  def new_game() do
    players = [{:p1, :bot}, {:p2, :bot}, {:p3, :bot}, {:p4, :bot}]

    players
    |> Enum.each(fn {player_id, _} = player ->
      {:ok, _pid} = Callbreak.PlayerSupervisor.start_player(player)
      {:ok, _game_id} = Callbreak.GameTracker.create_or_join_game(player_id)
    end)
  end

  def observe() do
    Mix.ensure_application!(:wx)
    Mix.ensure_application!(:runtime_tools)
    Mix.ensure_application!(:observer)
    :observer.start()
  end

  def via_tuple(service_id) do
    {:via, Registry, {Callbreak.Registry, service_id}}
  end
end
