defmodule CallbreakWeb.HomeLive do
  require Logger
  use CallbreakWeb, :live_view

  alias Callbreak.{GameTracker, Player}

  # todo handle the case of conflicting player id
  # maybe append random numbers
  defp maybe_generate_player_id(%{"username" => username}) do
    if String.length(username) < Player.get_player_id_len(),
      do: Player.random_player_id(),
      else: username
  end

  def handle_event("join_game", params, socket) do
    player_id = maybe_generate_player_id(params)

    {:ok, game_id} = GameTracker.create_or_get_game()

    {:noreply,
     socket
     |> assign(player_id: player_id)
     |> push_navigate(to: ~p"/lobby/#{game_id}/?player_id=#{player_id}")}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(random_player_id: Player.random_player_id())
     |> assign(player_id_length: Player.get_player_id_len())}
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <h1>Welcome to Game Name</h1>
      <form phx-submit="join_game">
        <div class="flex flex-col">
          <label for="username">Join as:</label>
          <div>
            <input
              type="text"
              id="username"
              name="username"
              minlength={@player_id_length}
              placeholder="Username"
              value={@random_player_id}
            />
          </div>
        </div>
        <.button type="submit">Join</.button>
      </form>
    </div>
    """
  end
end
