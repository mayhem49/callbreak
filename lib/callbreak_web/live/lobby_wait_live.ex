defmodule CallbreakWeb.LobbyWaitLive do
  # This is a temp name 
  use CallbreakWeb, :live_view
  alias Callbreak.{Player, GameServer}

  def mount(%{"game_id" => game_id, "player_id" => player_id}, _session, socket) do
    if connected?(socket) do
      {:ok, _} = Player.register(player_id, self())
      :ok = GameServer.join_game(game_id, player_id)
    end

    socket =
      socket
      |> put_flash(:info, "[#{game_id}] joined successfully")
      |> assign(:player_id, player_id)
      |> assign(:game_id, game_id)
      |> assign(:opponents, [])

    {:ok, socket}
  end

  # todo play with bots only when there is only one player
  def render(assigns) do
    ~H"""
    <div class="container">
      <h1 class="font-bold text-center">Game Lobby <%= @game_id %></h1>
      <button
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        phx-click="play_bots"
        type="button"
      >
        play with bots
      </button>

      <div>player_id: <span class="font-bold"><%= @player_id %></span></div>

      <div class="py-4">
        <h1>waiting for players...</h1>
        <ul>
          <li><%= @player_id %></li>
          <%= for {player, _pos} <- @opponents do %>
            <li><%= player %></li>
          <% end %>
          <%= for _ <- 1..(3-Enum.count(@opponents)) do %>
            <li>.....</li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end
end
