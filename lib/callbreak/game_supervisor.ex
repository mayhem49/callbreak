defmodule Callbreak.GameSupervisor do
  @module_doc """
  This module supervises a single game consisting of four players.
  It supervises a GameServer and PlayerSupervisor(DynamicSupervisor) which supervises the four players playing the game.
  """
  use Supervisor

  def start_link({game_id, _} = init_args) do
    IO.inspect(__MODULE__)

    Supervisor.start_link(__MODULE__, init_args,
      name: Callbreak.service_name({Callbreak.GameSupervisor, game_id})
    )
  end

  @impl true
  def init({game_id, players}) do
    player_ids = Enum.map(players, fn {id, _} -> id end)

    children = [
      {Callbreak.PlayerSupervisor, {game_id, players}},
      {Callbreak.GameServer, {game_id, player_ids}}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

defmodule Callbreak.PlayerSupervisor do
  @module_doc """
  This module supervises four players in a game.
  """

  # But the players may leave and join the game as wish.
  # Each PlayerSupervisor is associated with a game. 
  # When the game terminates, the supervisor also terminates.
  use Supervisor

  def start_link({game_id, _} = init_args) do
    Supervisor.start_link(__MODULE__, init_args,
      name: Callbreak.service_name({__MODULE__, game_id})
    )
  end

  @impl true
  def init({game_id, players}) do
    children =
      Enum.map(players, fn {player_id, player_type} ->
        {Callbreak.Player, {game_id, player_id, player_type}}
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule Callbreak.GameDynamicSupervisor do
  use DynamicSupervisor

  @module_doc """
  This module supervises a GameSupervisor dynamically.
  """

  def start_link(init_args) do
    IO.puts(__MODULE__)
    DynamicSupervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def start_game({_, _} = init_args) do
    spec = {Callbreak.GameSupervisor, init_args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_init_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
