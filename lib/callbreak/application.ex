defmodule Callbreak.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

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
end

defmodule Test do
  alias Callbreak.Application

  @name :server
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: Application.via_tuple(@name))
  end

  def print do
    GenServer.call(Application.via_tuple(@name), :print)
  end

  @impl true
  def init(nil) do
    {:ok, nil}
  end

  @impl true
  def handle_call(:print, _from, state) do
    IO.inspect("print from genserver")
    {:noreply, state}
  end
end
