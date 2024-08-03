defmodule Callbreak.GameTracker do
  alias Callbreak.GameDynamicSupervisor
  use Callbreak.Constants

  require Logger

  @moduledoc """
  This module stores the available game to join, otherwise creates a new one.
  """

  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: Callbreak.GameTracker)
  end

  def create_or_get_game do
    GenServer.call(__MODULE__, :create_or_get_game)
  end

  def renew_game do
    GenServer.call(__MODULE__, :renew_game)
  end

  # callbacks
  @impl true
  def init([]) do
    {:ok, %{game_id: nil, count: 0}}
  end

  @impl true
  def handle_call(:renew_game, _from, state) do
    {:reply, :ok, %{state | game_id: nil, count: 0}}
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

  # private functions
  defp create_or_get_game(%{game_id: nil}) do
    game_id = random_game_id()
    {:ok, _pid} = GameDynamicSupervisor.start_game(game_id)
    Logger.info(game_created: game_id)
    game_id
  end

  defp create_or_get_game(%{game_id: game_id}) do
    game_id
  end

  def random_game_id do
    id =
      1..@game_id_len
      |> Enum.map(fn _ -> Enum.random(?a..?z) end)
      |> List.to_string()

    "game-#{id}"
  end
end
