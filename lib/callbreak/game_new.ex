defmodule Callbreak.GameNew do
  require Logger
  alias Callbreak.Hand

  #  game state
  #            :game_start             :game_complete
  #  :waiting -------------> :running ----------------> :complete

  #  hand state
  #  :hand_start          :hand_play_start             :hand_complete
  #             :bidding ------------------> :playing ----------------> :complete

  # trick starts at `:hand_play_start` | `:trick_winner`
  # trick ends `:trick_winner`

  # send *_complete message at the end (for instance, send :scorecard before :hand_complete
  # todo add rules regardig total bid count reachign 10


  @enforce_keys [
    :game_id,
    :players,
    :current_hand,
    :dealer,
    :current_player,
    :scorecard,
    :instructions,
    :game_state
  ]

  defstruct @enforce_keys

  alias __MODULE__, as: G

  # players: [] -> players play in cyclic order of the list

  # current_hand: Callbreak.Hand 
  # Each callbreak game, consists of 5 rounds (k.a hand)
  # Each hand consists of bidding phase and then playing phase
  # Each hand constains 13 playing phases, known as trick

  # dealer: player -> player who dealt the hand
  # review: may be store in the Hand module (or maybe store index in the players list)

  # current_player: player -> players whose turn it is to play

  # scorecard: todo

  # instructions: [] -> accumulate instructions for players

  # game_state: :waiting, :running, :complete

  def new(game_id) do
    %G{
      game_id: game_id,
      players: [],
      current_hand: nil,
      dealer: nil,
      current_player: nil,
      scorecard: [],
      instructions: [],
      game_state: :waiting
    }
  end

  def join_game(%G{} = game, player) do
    game
    |> handle_join_game(player)
    |> handle_game_action_result(game, player)
  end

  def make_bid(%G{} = game, player, bid) do
    game
    |> handle_make_bid(player, bid)
    |> handle_game_action_result(game, player)
  end

  def play_card(%G{} = game, player, card) do
    game
    |> handle_play_card(player, card)
    |> handle_game_action_result(game, player)
  end

  defp handle_game_action_result(result, game, player) do
    case result do
      %G{} = game ->
        return_instructions_and_game(game)

      {:error, _} = error ->
        game
        |> notify_player(player, error)
        |> return_instructions_and_game()
    end
  end


  # todo: timer logic is not copied in this module
  # code concerning notify_server

  # JOIN
  defp handle_join_game(%G{game_state: :waiting} = game, player) do
    %{players: players} = game

    %{game | players: [player | players]}
    |> notify_player(player, {:opponents, players})
    |> notify_except(player, {:new_player, player})
    |> maybe_start_game()
  end

  defp handle_join_game(%G{} = game, player), do: {:error, :game_already_started}

  defp maybe_start_game(%G{players: players} = game) when length(players) < 4, do: game

  # A started game is in :running or :complete state
  defp maybe_start_game(%G{players: players} = game) when length(players) == 4 do
    # for each player, notify the opponents in :left, :top, and :right position
    notify_opponents =
      players
      |> Enum.with_index()
      |> Enum.map(fn {player, index} ->
        map_index_to_player = fn i -> Enum.at(game.players, Integer.mod(i, length(players))) end

        opponents = %{
          left: map_index_to_player.(index + 1),
          top: map_index_to_player.(index + 2),
          right: map_index_to_player.(index + 3)
        }

        player_instruction(player, {:opponents, opponents})
      end)

    # dealer is chosen at random at the start
    # this will be overrided at `start_new_hand`
    %{game | game_state: :running, dealer: Enum.random(game.players)}
    |> add_instructions(notify_opponents)
    |> notify_all(:game_start)
    |> start_new_hand()
  end


  # BID
  defp handle_make_bid(%G{current_player: player} = game, player, bid) do
    with {:ok, hand, bidding_completed?} <- Hand.take_bid(game.current_hand, player, bid) do
      game =
        %{game | current_hand: hand}
        |> notify_all({:bid, player, bid})
        |> cycle_current_player()

      if bidding_completed? do
        game |> notify_all(:hand_play_start) |> ask_current_player_to_play()
      else
        game
        |> ask_current_player_to_bid()
      end
    end
  end

  # out of turn biding
  defp handle_make_bid(%G{} = game, player, _bid) do
    {:error, :out_of_turn}
  end

  # maybe make guard for turn checking, review
  # and maybe also refactor the error into some common function and throw error there?
  # instead of another function clause for every public function which is the case currently? 

  # PLAY

  def handle_play_card(%G{current_player: player} = game, player, card) do
    with {:ok, hand, trick_winner, hand_scorecard} <-
           Hand.play_card(game.current_hand, player, card) do
      game =
        %{game | current_hand: hand}
        |> notify_all({:play, player, card})

      # TODO: refactor this
      if trick_winner do
        game =
          %{game | current_player: trick_winner}
          |> notify_all({:trick_winner, trick_winner})

        # hand is completed only if trick is completed
        if hand_scorecard,
          do: handle_hand_completion(game, hand_scorecard),
          else: ask_current_player_to_play(game)

      else
        game
        |> cycle_current_player()
        |> ask_current_player_to_play()
      end
    end
  end

  def handle_play_card(%G{} = game, player, _card) do
    {:error, :out_of_turn}
  end

  # todo: review
  # review don't use Map.put / Map.get
  defp calculate_points(scorecard) do
    acc =
      Enum.reduce(scorecard, %{}, fn trick_scorecard, acc ->
        Enum.reduce(trick_scorecard, acc, fn {player, {bid, extra_trick}}, acc ->
          Map.update(acc, player, {bid, extra_trick}, fn
            # round second el to first el todo
            {curr_bid, curr_extra_trick} -> {curr_bid + bid, curr_extra_trick + extra_trick}
          end)
        end)
      end)

    Enum.reduce(acc, %{}, fn
      {player, {bid, extra_trick}}, acc -> Map.put(acc, player, bid + extra_trick / 10)
    end)
  end

  # TODO: review
  defp handle_hand_completion(game, hand_scorecard) do
    acc_scorecard = [hand_scorecard | game.scorecard]

    hand_score = calculate_points([hand_scorecard])
    acc_score = calculate_points(acc_scorecard)

    %{game | scorecard: acc_scorecard}
    |> notify_all({:scorecard, hand_score, acc_score})
    |> notify_all(:hand_complete)
    |> handle_game_completion()
  end

  # TODO: review
  defp handle_game_completion(game) do
    if Enum.count(game.scorecard) == 5 do
      game
      |> notify_all({:winner, "random player for now"})
      |> notify_server(:game_completed)
    else
      start_new_hand(game)
    end
  end



  defp start_new_hand(%G{} = game) do
    {dealer, current_player} = get_next_two_player(game, game.dealer)

    {hand, player_cards} = Hand.start_new(game.players)

    notify_cards =
      Enum.map(player_cards, fn {player, cards} ->
        player_instruction(player, {:cards, dealer, cards})
      end)

    %{game | current_hand: hand, dealer: dealer, current_player: current_player}
    |> add_instructions(notify_cards)
    |> notify_all(:hand_start)
    |> ask_current_player_to_bid()
  end

  defp cycle_current_player(game) do
    %{game | current_player: get_next_player(game, game.current_player)}
  end

  defp get_next_two_player(game, curr_player) do
    next_player = get_next_player(game, curr_player)
    {next_player, get_next_player(game, next_player)}
  end

  defp get_next_player(game, curr_player) do
    # make it better review
    player_index = Enum.find_index(game.players, fn player -> player == curr_player end)
    new_curr_index = Integer.mod(player_index + 1, length(game.players))
    Enum.at(game.players, new_curr_index)
  end

  #  NOTIFICATION

  # message is sent to player
  # instruction is for gameserver
  defp player_instruction(player, message), do: {:notify_player, player, message}

  defp ask_current_player_to_play(%G{} = game) do
    notify_current_player(game, :play)
  end

  defp ask_current_player_to_bid(%G{} = game) do
    notify_current_player(game, :bid)
  end

  defp notify_current_player(game, message) do
    notify_player(game, game.current_player, message)
  end

  defp notify_player(game, player, message) do
    %G{game | instructions: [player_instruction(player, message) | game.instructions]}
  end

  defp notify_server(game, message) do
    %G{game | instructions: [{:notify_server, message} | game.instructions]}
  end

  defp notify_except(game, except_player, message) do
    Enum.reduce(game.players, game, fn
      ^except_player, game ->
        game

      player, game ->
        notify_player(game, player, message)
    end)
  end

  defp notify_all(game, message) do
    Enum.reduce(game.players, game, fn player, game ->
      notify_player(game, player, message)
    end)
  end

  defp add_instructions(game, instructions) when is_list(instructions) do
    %{game | instructions: instructions ++ game.instructions}
  end

  defp return_instructions_and_game(game) do
    {Enum.reverse(game.instructions), %{game | instructions: []}}
  end
end

# messages

# {:error , error}
# error :
# returned by Hand.take_bid
# :game_already_started
# :out_of_turn

# current_player
# :bid
# :play

# all player
# {:opponents, [player]} two versions
# {:new_player, player}
# {:cards, dealer, cards}
# :game_start
# hand_start
# {:cards, dealer, cards}
