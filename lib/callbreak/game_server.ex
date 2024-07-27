defmodule Callbreak.GameServer do
  use GenServer
  alias Callbreak.{Game, Player}
  require Logger

  def start_link(game_id) do
    IO.puts("starting_game: #{game_id}")
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def bid(game_id, player_pid, bid) do
    return = GenServer.cast(via_tuple(game_id), {:bid, player_pid, bid})
    return
  end

  def play(game_id, player_pid, play_card) do
    GenServer.cast(via_tuple(game_id), {:play, player_pid, play_card})
  end

  def join_game(game_id, player_id),
    do: GenServer.call(via_tuple(game_id), {:join, player_id})

  # call_back
  @impl true
  def init(game_id) do
    {:ok,
     game_id
     |> Game.new()
     |> handle_game_instructions()}
  end

  @impl true
  def handle_cast({:play, player, play_card}, game) do
    game =
      game
      |> Game.handle_play(player, play_card)
      |> handle_game_instructions()

    {:noreply, game}
  end

  @impl true
  def handle_cast({:bid, player, bid}, game) do
    IO.inspect({player, bid}, label: "bid")

    game =
      game
      |> Game.handle_bid(player, bid)
      |> handle_game_instructions()

    {:noreply, game}
  end

  @impl true
  def handle_call({:join, player}, _self, game) do
    IO.inspect("join #{inspect(player)}")

    game =
      game
      |> Game.join_game(player)
      |> handle_game_instructions()

    {:reply, :ok, game}
  end

  @impl true
  def handle_info(:kill_self, state) do
    Logger.warning("shutting down game_server: #{state.game_id}")
    {:stop, :normal, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.warning("inside terminate of game_server")
    :ok
  end

  defp handle_game_instructions({instructions, game}) do
    Enum.each(instructions, &handle_instruction(&1))
    game
  end

  defp handle_instruction({:notify_player, player, message_payload}) do
    Player.notify_liveview(player, message_payload)
  end

  defp handle_instruction({:notify_server, :game_completed}) do
    # since the handler for this message will be run only after 
    # the current message execution is completed, this should be fine
    # bot will kill when they receive {:winner,winner} message
    Process.send(self(), :kill_self, [:noconnect])
  end

  defp via_tuple(game_id) do
    Callbreak.Application.via_tuple(game_id)
  end
end
