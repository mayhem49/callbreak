defmodule Callbreak.GameServerNew do
  @moduledoc false
  use GenServer
  alias Callbreak.Player
  alias Callbreak.GameNew, as: Game
  require Logger

  use Callbreak.Constants

  alias __MODULE__, as: GS

  def start_link(game_id) do
    Logger.info("starting_game: #{game_id}")
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def bid(game_id, player_pid, bid) do
    GenServer.cast(via_tuple(game_id), {:bid, player_pid, bid})
  end

  def play(game_id, player_pid, play_card) do
    GenServer.cast(via_tuple(game_id), {:play, player_pid, play_card})
  end

  def join_game(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:join, player_id})
  end

  # call_back

  # game is the game state, the ultimate source of truth

  # :timer -> reference to the timer
  # -> When a player is asked to perform an action, a timer is started
  # When the timer ends, handle_info is called with {:move_id, move_id} 
  # if the current move_id of game_server is equal to the move_id in timer message,
  # --> No move has been made by the player, so `autoplay`
  # if move_id of server > move_id of timer message
  # the move has been played by the player, so ignore the message, technically cancelling the timer

  # an alternative is to store the timer reference and call cancel_timer, but a problem arises:
  # When the timer ends after the player performs an move,
  # We need a mechanism for that situation
  # The above mentioned way eliminates that situation, without the headache of timer reference

  # todo
  # timer should only be used in multiplayer mode?
  # allow different player differnt time corr. to the move order (high for first, and decrease for succeeding move)?

  @impl true
  def init(game_id) do
    game = Game.new(game_id)
    {:ok, %{game: game, move_id: 0}}
  end

  def handle_cast({:play, player, card}, %{game: game} = state) do
    state =
      game
      |> Game.play_card(player, card)
      |> handle_instructions(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:bid, player, bid} = msg, %{game: game} = state) do
    Logger.info("#{inspect(msg)}")

    state =
      game
      |> Game.handle_bid(player, bid)
      |> handle_instructions(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:join, player} = msg, _self, %{game: game} = state) do
    Logger.info("#{inspect(msg)}")

    state =
      game
      |> Game.join_game(player)
      |> handle_instructions(state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:kill_self, state) do
    Logger.info("shutting down game_server: #{state.game.game_id}")
    {:stop, :normal, state}
  end

  # the plyaer for which the timer was started has already made the move
  def handle_info({:timer, move_id} = msg, %{game: game} = state)
      when move_id < state.move_id do
    {:noreply, state}
  end

  def handle_info({:timer, move_id} = msg, %{game: game} = state)
      when move_id == state.move_id do
    Logger.info("#{inspect(msg)}")

    # autoplay is true by default now, do: something
    if @autoplay do
      Logger.info("timeout- move_id: #{inspect(msg)} game_id: #{state.game.game_id}")

      state =
        game
        |> Game.handle_autoplay()
        |> handle_instructions(state)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("UNHANDLED HANDLE_INFO msg: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, %{game: %{game_id: game_id}}) do
    Logger.info("Terminating game server #{game_id}. reason: #{inspect(reason)} ")
    :ok
  end

  # private functions
  defp handle_instructions({instructions, game}, state) do
    state = %{state | game: game}

    Enum.reduce(instructions, state, fn instruction, state ->
      handle_instruction(state, instruction)
    end)
  end

  # the `Game` module will explicitly specify to start the timer and kill the timer

  # set timer on {:to_server, :expect_move} instruction
  # the current move are bidding and card playing

  # cancel timer on {:to_server, :cancel_timer} instruction
  # timer is cancelled/invalidated when you update the `move_id` in the game_server state

  # the timer will be handled in handled_info if the timer hasnot been cleared(incremented)

  defp handle_instruction(state, {:to_server, :move_received}) do
    Logger.info("clearing timer: #{state.move_id}")
    %{state | move_id: state.move_id + 1}
  end

  defp handle_instruction(state, {:to_server, :expect_move}) do
    move_id = state.move_id + 1

    Process.send_after(self(), {:timer, move_id}, @allowed_move_time_ms)
    Logger.info("setting timer: #{move_id}")

    %{state | move_id: move_id}
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

  defp via_tuple(game_id) do
    Callbreak.Application.via_tuple(game_id)
  end
end
