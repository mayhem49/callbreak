defmodule Callbreak.GameServer do
  use GenServer
  alias Callbreak.{Game, Player}

  def start_link({game_id, player_id}) do
    IO.puts("starting_game: #{game_id}")
    GenServer.start_link(__MODULE__, {game_id, player_id}, name: via_tuple(game_id))
  end

  def bid(game_id, player_id, bid),
    do: GenServer.cast(via_tuple(game_id), {:bid, player_id, bid})

  def play(game_id, player_id, play_card),
    do: GenServer.cast(via_tuple(game_id), {:play, player_id, play_card})

  def join_game(game_id, player_id),
    do: GenServer.call(via_tuple(game_id), {:join, player_id})

  # call_back
  @impl true
  def init({game_id, player_id}) do
    {:ok,
     {game_id, player_id}
     |> Game.new()
     |> handle_game_instructions()}
  end

  @impl true
  def handle_call({:join, player}, _self, game) do
    IO.inspect("join #{player}")
    # todo get existing opponents
    game =
      game
      |> Game.join_game(player)
      |> handle_game_instructions()

    {:reply, :ok, game}
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

  defp handle_game_instructions({instructions, game}) do
    Enum.each(instructions, &handle_instruction(&1))
    game
  end

  defp handle_instruction({:notify_player, player, message_payload}) do
    Player.notify(player, message_payload)
  end

  defp via_tuple(game_id) do
    Callbreak.via_tuple(game_id)
  end
end
