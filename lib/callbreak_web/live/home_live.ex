defmodule CallbreakWeb.HomeLive do
  require Logger
  use CallbreakWeb, :live_view
  alias Phoenix.LiveView.JS

  alias Callbreak.{GameTracker, Player}

  defp maybe_generate_player_id(%{"username" => username}) do
    if String.length(username) < Player.get_player_id_len(),
      do: Player.random_player_id(),
      else: "player-" <> username
  end

  def handle_event("join_game", params, socket) do
    player_id = maybe_generate_player_id(params)

    {:ok, game_id} = GameTracker.create_or_get_game()
    Logger.info("Game created #{game_id}")

    socket
    |> assign(player_id: player_id)

    {:noreply, push_navigate(socket, to: ~p"/lobby/#{game_id}/?player_id=#{player_id}")}
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <h1>Welcome to Game Name</h1>
      <form phx-submit="join_game">
        <div class="input-group">
          <label for="username">Enter your username:</label>

          <div class="flex flex-row">
            <input type="text" id="username" name="username" minlength="6" placeholder="Username" />
            <button
              type="button"
              phx-click={
                JS.dispatch("lobby:generate_player_id",
                  to: "#username",
                  detail: %{length: Player.get_player_id_len()}
                )
              }
            >
              random
            </button>
          </div>
        </div>
        <button type="submit">Join</button>
      </form>
    </div>
    """
  end
end
