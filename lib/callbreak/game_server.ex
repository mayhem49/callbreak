defmodule Callbreak.GameServer do
  use GenServer
  alias Callbreak.{Game, Player}

  def start_link({game_id, players}) do
    IO.puts("starting_game: #{game_id}")
    GenServer.start_link(__MODULE__, {game_id, players}, name: Callbreak.service_name(game_id))
  end

  def bid(game_id, player_id, bid),
    do: GenServer.cast(Callbreak.service_name(game_id), {:bid, player_id, bid})

  def play(game_id, player_id, play_card),
    do: GenServer.cast(Callbreak.service_name(game_id), {:play, player_id, play_card})

  # call_back
  @impl true
  def init({game_id, players}) do
    {:ok,
     {game_id, players}
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
end
