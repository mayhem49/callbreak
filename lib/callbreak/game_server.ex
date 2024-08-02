defmodule Callbreak.GameServer do
  use GenServer
  alias Callbreak.{Game, Player}
  require Logger
  # in milliseconds
  @timer 5 * 1000

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
    game = Game.new(game_id)
    {:ok, %{game: game, timer: 0}}
  end

  def handle_cast({:play, player, play_card}, %{game: game} = state) do
    state =
      game
      |> Game.handle_play(player, play_card)
      |> handle_game_instructions(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:bid, player, bid}, %{game: game} = state) do
    IO.inspect({player, bid}, label: "bid")

    state =
      game
      |> Game.handle_bid(player, bid)
      |> handle_game_instructions(state)

    {:noreply, state}
  end

  @impl true
  def handle_call({:join, player}, _self, %{game: game} = state) do
    IO.inspect("join #{inspect(player)}")

    state =
      game
      |> Game.join_game(player)
      |> handle_game_instructions(state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:kill_self, state) do
    Logger.warning("shutting down game_server: #{state.game.game_id}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:timer, timer} = msg, %{game: game} = state) do
    Logger.info("#{inspect(msg)}")

    if timer == state.timer do
      Logger.warning("timeout- timer: #{inspect(msg)} game_id: #{state.game.game_id}")
      Logger.warning("auto play")
      # todo autoplay
      state =
        game
        |> Game.handle_autoplay()
        |> handle_game_instructions(state)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("unhandled handle_info msg: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, %{game: %{game_id: game_id}}) do
    Logger.warning("Terminating game server #{game_id}. reason: #{inspect(reason)} ")
    :ok
  end

  # private functions
  defp handle_game_instructions({instructions, game}, state) do
    state = %{state | game: game}

    Enum.reduce(instructions, state, fn instruction, state ->
      handle_instruction(state, instruction)
    end)
  end

  defp handle_instruction(state, {:notify_player, player, message_payload}) do
    Player.notify_liveview(player, message_payload)
    state
  end

  defp handle_instruction(state, {:notify_server, :game_completed}) do
    # since the handler for this message will be run only after 
    # the current message execution is completed, this should be fine
    # bot will kill when they receive {:winner,winner} message
    Process.send(self(), :kill_self, [:noconnect])
    state
  end

  # maybe ok tuple was better for tthis anyway
  # After every success operation, current_player will be asked to do something unless the game is completed
  # so updating the current timer value will invalidate the current timer message 
  # and then set a new timer if the game is not completed
  # the timer will be handled in handled_info only when the currnet value of timer is equal to the timer value in message
  defp handle_instruction(state, {:notify_server, :success}) do
    Logger.error("clearing timer: #{state.timer}")
    timer = state.timer + 1

    if Game.is_running?(state.game) do
      Process.send_after(self(), {:timer, timer}, @timer)
      Logger.error("setting timer: #{timer}")
    end

    %{state | timer: timer}
  end

  defp handle_instruction(state, {:notify_server, :error}) do
    state
  end

  defp via_tuple(game_id) do
    Callbreak.Application.via_tuple(game_id)
  end
end
