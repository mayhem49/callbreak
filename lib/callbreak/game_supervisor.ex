defmodule Callbreak.GameDynamicSupervisor do
  use DynamicSupervisor

  require Logger

  @moduledoc """
  This module supervises GameServers.
  """

  def start_link(init_args) do
    Logger.info("starting #{__MODULE__}")
    DynamicSupervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def start_game(game_id) when is_binary(game_id) do
    child_spec = Supervisor.child_spec({Callbreak.GameServer, game_id}, restart: :transient)
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @impl true
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule Callbreak.PlayerSupervisor do
  @moduledoc """
  This module supervises bot players now.
  since player are liveview process and supervises by other supervisors, I guess.
  """

  use DynamicSupervisor

  # But the players may leave and join the game as wish.
  # Each PlayerSupervisor is associated with a game.
  # When the game terminates, the supervisor also terminates.

  def start_link(init_arg) do
    Process.info(self(), :current_stacktrace)
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init([]) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_player(player) do
    child_spec = Supervisor.child_spec({Callbreak.Player, player}, restart: :transient)
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def start_bot({_, _} = args) do
    child_spec = Supervisor.child_spec({Callbreak.Player.Bot, args}, restart: :transient)
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
