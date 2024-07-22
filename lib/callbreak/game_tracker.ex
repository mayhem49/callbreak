defmodule Callbreak.GameTracker do
  alias Callbreak.Player
  alias Callbreak.GameServer
  alias Callbreak.GameDynamicSupervisor

  @moduledoc """
  This module stores the available game to join, otherwise creates a new one.
  """

  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: Callbreak.GameTracker)
  end

  def create_or_get_game(),
    do: GenServer.call(__MODULE__, :create_or_get_game)

  # callbacks
  @impl true
  def init([]) do
    {:ok, %{game_id: nil, count: 0}}
  end

  @impl true
  def handle_call(:create_or_get_game, _from, state) do
    game_id = create_or_get_game(state)

    state =
      if state.count == 3,
        do: %{state | game_id: nil, count: 0},
        else: %{state | game_id: game_id, count: state.count + 1}

    {:reply, {:ok, game_id}, state}
  end

  # todo maybe start_game with game_id only
  # and after that join game?
  defp create_or_get_game(%{game_id: nil}) do
    game_id = random_game_id()
    {:ok, _pid} = GameDynamicSupervisor.start_game(game_id)
    game_id
  end

  defp create_or_get_game(%{game_id: game_id}) do
    game_id
  end

  def random_game_id() do
    id =
      1..5
      |> Enum.map(fn _ -> Enum.random(?a..?z) end)
      |> List.to_string()

    "game-#{id}"
  end
end