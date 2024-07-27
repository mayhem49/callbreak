defmodule Callbreak.Player.Bot do
  use GenServer
  alias Callbreak.{Application, GameServer, Player, Card, Trick}

  require Logger

  def start_link({player_id, game_id} = init_arg) do
    Logger.info("Bot Player started #{player_id} #{game_id}")
    GenServer.start_link(__MODULE__, init_arg, name: Application.via_tuple(player_id))
  end

  @impl true
  def init({player_id, game_id}) do
    {:ok, Player.new(player_id, game_id)}
  end

  # final
  @impl true
  def handle_cast({:new_player, new_player} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.add_new_opponent(state, new_player)}
  end

  def handle_cast({:opponents, opponents} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.add_opponents(state, opponents)}
  end

  def handle_cast({:game_start, opponents} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.set_opponents_final(state, opponents)}
  end

  def handle_cast({:cards, _dealer, cards} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.set_cards(state, cards)}
  end

  @impl true
  def handle_cast(:bid = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    bid = bot_bid(state)
    GameServer.bid(state.game_id, state.player_id, bid)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:bid, bidder, bid} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")

    {:noreply, Player.set_bid(state, bidder, bid)}
  end

  def handle_cast(:play = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")
    # sleeeping is mainly necessary when playing all four bots
    # for some reason logger doesn't print all the messages 
    # it is because of threshold limit of logger which is 500
    :timer.sleep(:rand.uniform(500))
    play_card = bot_play(state)
    GameServer.play(state.game_id, state.player_id, play_card)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:play, player, card} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")
    {:noreply, Player.handle_play(state, player, card)}
  end

  def handle_cast({:trick_winner, winner} = msg, state) do
    Logger.info("#{inspect(state.player_id)}  #{inspect(msg)}")
    {:noreply, Player.handle_trick_completion(state, winner)}
  end

  def handle_cast({:winner, _winner} = msg, state) do
    Logger.warning("#{inspect(state.player_id)}  #{inspect(msg)}")
    Logger.warning("BOT #{inspect(state.player_id)} shutting down")

    {:stop, :normal, state}
  end

  def handle_cast(:play_start, state) do
    {:noreply, state}
  end

  def handle_cast({:scorecard, _, _}, state) do
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    Logger.warning("UNHANDLED MESSAGE #{inspect(state.player_id)}  #{inspect(msg)}")
    {:noreply, state}
  end

  # utilities
  # for now
  def bot_bid(_state) do
    3
  end

  def bot_play(state) do
    Enum.random(Player.get_playable_cards(state))
  end
end

# currently some messages are required to be sent by game server to handle the ui change
# but are not necessaary for the bot
# may be usig pubsub, that can be made more efficient
