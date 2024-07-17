defmodule Callbreak do
  use Application

  @impl true
  def start(_start_type, _start_args) do
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
end
