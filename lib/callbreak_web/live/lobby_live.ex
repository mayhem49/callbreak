defmodule CallbreakWeb.LobbyLive do
  alias Callbreak.Card
  alias Callbreak.GameTracker
  alias Callbreak.PlayerSupervisor
  alias Callbreak.GameServer
  alias Callbreak.Player
  alias Callbreak.Player.Render
  require Logger

  @timer_el_id "timer"
  # in seconds
  @timer 5

  use CallbreakWeb, :live_view
  # current_state: :waiting | :bidding | :playing | :completed
  # :waiting | :playing -> :bidding, when {:cards, dealer, cards is received
  # :bidding -> :playing, when :play_start is received
  #  maybe bidding? is redundant?

  # only valid after waiting state is completed
  # current_player whose turn to play/bid
  # updated after every bid and every play, trick completion and when {:cards, dealer, cards}
  # mount
  def mount(%{"game_id" => game_id, "player_id" => player_id}, _session, socket) do
    if connected?(socket) do
      {:ok, _} = Player.register(player_id, self())
      :ok = GameServer.join_game(game_id, player_id)
    end

    state = Player.new(player_id, game_id)
    state = Player.set_cards(state, Callbreak.Deck.get_random_cards())

    socket =
      socket
      |> put_flash(:info, "[#{game_id}] joined successfully")
      |> assign(current_state: :waiting)
      |> assign(state: state)
      |> assign(dealer: nil)
      |> assign(current_player: nil)
      |> assign(show_scorecard: false)

    {:ok, socket}
  end

  # handle-cast
  def handle_cast({:opponents, opponents} = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply,
     socket
     |> assign(state: Player.add_opponents(socket.assigns.state, opponents))}
  end

  def handle_cast({:new_player, new_player} = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply,
     socket
     |> assign(state: Player.add_new_opponent(socket.assigns.state, new_player))}
  end

  def handle_cast({:game_start, opponents} = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply,
     socket
     |> assign(state: Player.set_opponents_final(socket.assigns.state, opponents))}
  end

  def handle_cast({:cards, dealer, cards} = msg, socket) do
    Logger.info("#{inspect(msg)}")

    current_player = Player.get_next_turn(socket.assigns.state, dealer)

    {:noreply,
     socket
     |> assign(dealer: dealer)
     |> assign(current_player: current_player)
     |> assign(current_state: :bidding)
     |> assign(state: Player.set_cards(socket.assigns.state, cards))}
  end

  def handle_cast(:bid = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply, socket |> push_event("start-timer", %{timer: @timer, id: @timer_el_id})}
  end

  def handle_cast({:bid, player, bid} = msg, socket) do
    Logger.info("#{inspect(msg)}")
    state = Player.set_bid(socket.assigns.state, player, bid)

    %{current_player: current_player} = socket.assigns
    current_player = Player.get_next_turn(state, current_player)

    {:noreply,
     socket
     |> assign(current_player: current_player)
     |> assign(state: state)
     |> then(fn socket ->
       if socket.assigns.state.player_id == player,
         do: socket |> put_flash(:info, "bid success"),
         else: socket
     end)}
  end

  def handle_cast(:play_start = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply,
     socket
     |> assign(current_state: :playing)}
  end

  def handle_cast(:play = msg, socket) do
    Logger.info("#{inspect(msg)}")

    # timer is set after :play and :bid message
    {:noreply, socket |> push_event("start-timer", %{timer: @timer, id: @timer_el_id})}
  end

  def handle_cast({:trick_winner, winner} = msg, socket) do
    Logger.info("#{inspect(msg)}")
    state = Player.handle_trick_completion(socket.assigns.state, winner)

    {:noreply,
     socket
     |> assign(current_player: winner)
     |> assign(state: state)}
  end

  def handle_cast({:play, player, card} = msg, socket) do
    Logger.info("#{inspect(msg)}")
    state = Player.handle_play(socket.assigns.state, player, card)

    %{current_player: current_player} = socket.assigns
    current_player = Player.get_next_turn(socket.assigns.state, current_player)

    {:noreply,
     socket
     |> assign(current_player: current_player)
     |> put_flash(:info, "your turn")
     |> assign(state: state)}
  end

  def handle_cast({:scorecard, hand_score, total_score} = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply,
     socket
     |> assign(show_scorecard: true)
     |> assign(state: Player.handle_scorecard(socket.assigns.state, hand_score, total_score))}
  end

  def handle_cast({:winner, _winner} = msg, socket) do
    Logger.info("#{inspect(msg)}")

    {:noreply,
     socket
     |> assign(current_state: :completed)
     |> assign(show_scorecard: true)}
  end

  def handle_cast(msg, socket) do
    Logger.warning(" UNHANDLED MESSAGE #{inspect(msg)}")
    {:noreply, socket}
  end

  # handle_info
  # this is called after @timer seconds
  # if there have been no move by the player 
  # maybe do it in genserver
  # handle it 

  # handle-event
  def handle_event("navigate_home", _params, socket) do
    Logger.warning("navigate_home")

    {:noreply,
     socket
     |> push_navigate(to: ~p"/live")}
  end

  def handle_event("hide_scorecard", _params, socket) do
    Logger.warning("hide_scorecard")

    {:noreply,
     socket
     |> assign(show_scorecard: false)}
  end

  def handle_event("card_play", %{"card_index" => card_index} = _params, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns.state

    card_index = String.to_integer(card_index)
    play_card = Enum.at(socket.assigns.state.cards, card_index)

    GameServer.play(game_id, player_id, play_card)

    {:noreply, socket}
  end

  def handle_event("bid", %{"bid" => bid}, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns.state
    bid = String.to_integer(bid)

    GameServer.bid(game_id, player_id, bid)

    {:noreply, socket}
  end

  def handle_event("play_bots", _params, socket) do
    %{opponents: opponents, game_id: game_id} = socket.assigns.state

    bot_count = 3 - Enum.count(opponents)

    # since we are directly joining to the known game,
    # and on doing so gametracker doesnot know about it.
    :ok = GameTracker.renew_game()

    Enum.each(1..bot_count, fn _ ->
      bot_id = Player.random_player_id()
      {:ok, _bot_pid} = PlayerSupervisor.start_bot({bot_id, game_id})
      GameServer.join_game(game_id, bot_id)
    end)

    {:noreply, socket}
  end

  def handle_event(event, _params, socket) do
    Logger.warning("UNHANDLED EVENT #{inspect(event)}")
    {:noreply, socket}
  end

  # todo play with bots only when there is only one player
  def render(%{current_state: :waiting} = assigns) do
    ~H"""
    <div class="container">
      <h1>Game Lobby</h1>
      <button
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        phx-click="play_bots"
        type="button"
      >
        play with bots
      </button>

      <div>
        This is a game lobby.
      </div>

      <div>
        <div>player_id: <%= @state.player_id %></div>
        <div>game_id: <%= @state.game_id %></div>
      </div>

      <div>
        <h1>waiting for players</h1>
        <ul>
          <li><%= @state.player_id %></li>
          <%= for {player, _pos} <- @state.opponents do %>
            <li><%= player %></li>
          <% end %>
          <%= for _ <- 1..(3-Enum.count(@state.opponents)) do %>
            <li>.....</li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  def render(assigns) do
    winner = if assigns.current_state == :completed, do: Player.get_winner(assigns.state)

    assigns =
      assigns
      |> assign(winner: winner)
      |> assign(current_trick: Render.get_current_trick_cards(assigns.state))
      |> assign(current_cards: Render.get_cards(assigns.state))

    ~H"""
    <div class="board-container  top">
      <div id="timer"></div>
      <%= for {player, position} <- @state.opponents do %>
        <%= player(assigns, player, position) %>
        <div class={"card_area opponent card_area-#{position}"}>
          <%= for {_,_i} <- Enum.with_index(@current_cards) do %>
            <div>c</div>
          <% end %>
        </div>
      <% end %>

      <%= for {position, {_, suit} = card} <- @current_trick do %>
        <div class={"card-play #{position} #{if suit in [:spade, :club], do: "card-black", else: "card-red"}"}>
          <span><%= Callbreak.Card.card_to_string(card) %></span>
          <span><%= Callbreak.Card.card_to_string(card) %></span>
        </div>
      <% end %>

      <section
        :if={@current_state == :bidding and @current_player == @state.player_id}
        class="bidding"
      >
        <%= for v <- 1..13 do %>
          <span class="bid" phx-click={JS.dispatch("clear-timer") |> JS.push("bid")} phx-value-bid={v}>
            <%= v %>
          </span>
        <% end %>
      </section>

      <%= player(assigns, @state.player_id, :bottom) %>

      <div id="cards-container" class="card_area  card_area-bottom ">
        <%= for card <- @current_cards do %>
          <%= render_card(assigns, card) %>
        <% end %>
      </div>

      <.scorecard_modal
        :if={@show_scorecard}
        hand_scores={@state.hand_scores}
        scorecard={@state.scorecard}
        opponents={@state.opponents}
        player_id={@state.player_id}
        winner={@winner}
      />
    </div>
    """
  end

  def scorecard_modal(assigns) do
    # todo make it better

    scorecard = if assigns.scorecard, do: [assigns.scorecard], else: []

    hand_scores =
      if Enum.empty?(assigns.hand_scores),
        do: nil,
        else: Enum.reverse(assigns.hand_scores) ++ scorecard

    on_cancel =
      if assigns.winner, do: JS.push("navigate_home"), else: JS.push("hide_scorecard")

    assigns =
      assigns
      |> assign(hand_scores: hand_scores)
      |> assign(on_cancel: on_cancel)

    ~H"""
    <.button class="absolute" phx-click={show_modal("scorecard_modal")}>
      show modal
    </.button>

    <.modal :if={@hand_scores} on_cancel={@on_cancel} show id="scorecard_modal">
      <h1 :if={@winner}>!!! <%= @winner %> won !!!</h1>

      <.table id="hand_scores-table" rows={@hand_scores}>
        <:col :let={hand_score} label={@player_id}>
          <%= Map.get(hand_score, @player_id) %>
        </:col>

        <%= for  {_player, _pos} <- @opponents do %>
        <% end %>

        <:col :let={hand_score} :for={{player, _pos} <- @opponents} label={player}>
          <%= Map.get(hand_score, player, player) %>
        </:col>
      </.table>
    </.modal>
    """
  end

  def render_card(assigns, {index, {_rank, suit} = card, can_play?}) do
    is_turn? =
      assigns.current_state == :playing and assigns.current_player == assigns.state.player_id

    card_class = [
      "self-card",
      if(is_turn? and can_play?, do: "playable", else: "unplayable"),
      if(suit in [:spade, :club], do: "card-black", else: "card-red")
    ]

    assigns =
      assigns
      |> assign(card_class: card_class)
      |> assign(index: index)
      |> assign(card: card)

    ~H"""
    <div
      class={@card_class}
      phx-click={JS.dispatch("clear-timer") |> JS.push("card_play")}
      phx-value-card_index={@index}
    >
      <%= Card.card_to_string(@card) %>
    </div>
    """
  end

  def player(assigns, target_player, target_position) do
    assigns =
      assigns
      |> assign(target_player: target_player)
      |> assign(target_position: target_position)

    ~H"""
    <div class={"player player-#{@target_position} #{if @current_player == @target_player, do: "current-player", else: ""}"}>
      <div><strong><%= @target_player %></strong></div>
      <div>
        <%= Render.current_score_to_string(@state, @target_player) %>
      </div>
    </div>
    """
  end

  def loading(assigns) do
    ~H"""
    <div role="status">
      <svg
        aria-hidden="true"
        class="w-8 h-8 text-gray-200 animate-spin dark:text-blue-200 fill-blue-500"
        viewBox="0 0 100 101"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
          fill="currentColor"
        />
        <path
          d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
          fill="currentFill"
        />
      </svg>
    </div>
    """
  end
end

# maybe play_start can be inferred from :play or {:play, player, card} ?
