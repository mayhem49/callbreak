defmodule Callbreak.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias Callbreak.GameServer
  alias Callbreak.GameTracker
  alias Callbreak.PlayerSupervisor
  alias Callbreak.Player

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # callbreak app
      {Registry, keys: :unique, name: Callbreak.Registry},
      Callbreak.PlayerSupervisor,
      Callbreak.GameDynamicSupervisor,
      Callbreak.GameTracker,
      # callbreak app
      # Start the Telemetry supervisor
      CallbreakWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Callbreak.PubSub},
      # Start Finch
      {Finch, name: Callbreak.Finch},
      # Start the Endpoint (http/https)
      CallbreakWeb.Endpoint
      # Start a worker by calling: Callbreak.Worker.start_link(arg)
      # {Callbreak.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Callbreak.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CallbreakWeb.Endpoint.config_change(changed, removed)
    :ok
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

  def register(name, pid) do
    Registry.register(Callbreak.Registry, name, pid)
  end

  def play_bots() do
    # todo this will leave the existing game, if any, with incomplete players
    :ok = GameTracker.renew_game()
    {:ok, game_id} = GameTracker.create_or_get_game()
    :ok = GameTracker.renew_game()

    Enum.each(1..4, fn _ ->
      bot_id = Player.random_player_id()
      {:ok, _bot_pid} = PlayerSupervisor.start_bot({bot_id, game_id})
      GameServer.join_game(game_id, bot_id)
    end)
  end
end
