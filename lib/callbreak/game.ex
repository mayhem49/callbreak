defmodule Callbreak.Game do
  @moduledoc """
  The game is in one of four possible state. 
  - waiting
  - bidding
  - playing
  - completed

  After the waiting stage is completed, {:game_start, opponents} message is sent to players
  and bidding is started.

  Bidding and playing process are repeated five times.

  At the start of new hand, players are notified via {:cards, dealer, cards} message
  After the bidding stage is completed, :play_start, not to be confused with :game_start message is sent to each player.
  """
  defstruct [
    :game_id,
    :players,
    # tracks the current hand being played(all tricks and call and individual players' cards)
    :current_hand,
    # player who dealt the card
    :dealer,
    # player whose turn is it to play
    :current_player,
    # points table  of the game
    :scorecard,
    :instructions
  ]

  # todo don't allow same player to be joined twice

  # joining
  # playiing
  # end

  require Logger
  alias Callbreak.Hand

  def new(game_id) do
    game = %__MODULE__{
      game_id: game_id,
      players: [],
      current_hand: nil,
      dealer: nil,
      current_player: nil,
      scorecard: [],
      instructions: []
    }

    game
    |> return_instructions_and_game()
  end

  def join_game(%{players: players} = game, player_id)
      when length(players) < 4 do
    %{game | players: [player_id | players]}
    |> notify_player(player_id, {:opponents, players})
    |> notify_except(player_id, {:new_player, player_id})
    |> maybe_start_game()
    |> return_instructions_and_game()
  end

  def join_game(game, player_id) do
    game
    |> notify_player(player_id, :cannot_join_game)
    |> return_instructions_and_game()
  end

  # starts game after joining process is completed
  # also starts bidding process
  defp maybe_start_game(%{players: players} = game) when length(players) == 4 do
    game =
      game.players
      |> Enum.with_index()
      |> Enum.reduce(game, fn {player, index}, game ->
        # maybe call get_next_player?
        opponents = %{
          left: Integer.mod(index + 1, 4),
          top: Integer.mod(index + 2, 4),
          right: Integer.mod(index + 3, 4)
        }

        opponents =
          opponents
          |> Enum.map(fn {pos, index} -> {Enum.at(game.players, index), pos} end)
          |> Enum.into(%{})

        game
        |> notify_player(player, {:game_start, opponents})
      end)

    # set dealer which will be shifted by one position in new_hand
    game = %{game | dealer: Enum.random(game.players)}
    start_new_hand(game)
  end

  defp maybe_start_game(game), do: game

  defp start_new_hand(game) do
    # below code means:
    # randomly chose dealer in `new` will be shifted by one
    dealer = get_next_player(game, game.dealer)
    current_player = get_next_player(game, dealer)

    %{game | current_hand: Hand.new(), dealer: dealer, current_player: current_player}
    |> deal()
    |> ask_current_player_to_bid()
  end

  # also notifies the dealer using same message to notify cards
  defp deal(game = %__MODULE__{}) do
    {hand, cards} = Hand.deal(game.current_hand, game.players)

    Enum.reduce(cards, %{game | current_hand: hand}, fn {player, cards}, acc_game ->
      notify_player(acc_game, player, {:cards, game.dealer, cards})
    end)
  end

  def handle_bid(%{current_player: player} = game, player, bid) do
    case Hand.take_bid(game.current_hand, player, bid) do
      {:ok, hand} ->
        game
        |> Map.put(:current_hand, hand)
        |> notify_to_all({:bid, player, bid})
        |> rotate_current_player()
        |> maybe_start_play()
        |> return_instructions_and_game()

      {:error, err_msg} ->
        game
        |> notify_player(player, err_msg)
        |> return_instructions_and_game()
    end
  end

  # out of turn biding
  def handle_bid(game, player, _bid) do
    game
    |> notify_player(player, {:out_of_turn})
    |> return_instructions_and_game()
  end

  defp maybe_start_play(game) do
    if Hand.is_bidding_completed?(game.current_hand),
      do: game |> notify_to_all(:play_start) |> ask_current_player_to_play(),
      else: ask_current_player_to_bid(game)
  end

  def handle_play(%{current_player: player} = game, player, play_card) do
    case Hand.play(game.current_hand, player, play_card) do
      {:ok, hand, winner} ->
        game
        |> Map.put(:current_hand, hand)
        |> notify_to_all({:play, player, play_card})
        |> handle_trick_completion(winner)
        |> return_instructions_and_game()

      {:error, err_msg} ->
        game
        |> notify_player(player, err_msg)
        |> return_instructions_and_game()
    end
  end

  # out of turn play
  def handle_play(game, player, _card) do
    game
    |> notify_player(player, :out_of_turn)
    |> return_instructions_and_game()
  end

  # handle current trick completion
  # it cascades to `handle_hand_completion`
  # which cascades to `handle_game_completion`
  def handle_trick_completion(game, nil) do
    game
    |> rotate_current_player()
    |> ask_current_player_to_play()
  end

  def handle_trick_completion(game, winner) do
    game
    |> Map.put(:current_player, winner)
    |> notify_to_all({:trick_winner, winner})
    |> handle_hand_completion()
  end

  def handle_hand_completion(game) do
    case Hand.maybe_hand_completed(game.current_hand) do
      nil ->
        ask_current_player_to_play(game)

      hand_scorecard ->
        acc_scorecard = [hand_scorecard | game.scorecard]

        hand_score = calculate_points([hand_scorecard])
        acc_score = calculate_points(acc_scorecard)

        %{game | scorecard: acc_scorecard}
        |> notify_to_all({:scorecard, hand_score, acc_score})
        |> handle_game_completion()
    end
  end

  def handle_game_completion(game) do
    if Enum.count(game.scorecard) == 5 do
      game
      |> notify_to_all({:winner, "random player for now"})
      |> notify_server(:game_completed)
    else
      game
      |> start_new_hand()
    end
  end

  def calculate_points(scorecard) do
    acc =
      Enum.reduce(scorecard, %{}, fn trick_scorecard, acc ->
        Enum.reduce(trick_scorecard, acc, fn {player, {bid, extra_trick}}, acc ->
          Map.update(acc, player, {bid, extra_trick}, fn
            {curr_bid, curr_extra_trick} -> {curr_bid + bid, curr_extra_trick + extra_trick}
          end)
        end)
      end)

    Enum.reduce(acc, %{}, fn
      {player, {bid, extra_trick}}, acc -> Map.put(acc, player, bid + extra_trick / 10)
    end)
  end

  def return_instructions_and_game(game) do
    {Enum.reverse(game.instructions), %{game | instructions: []}}
  end

  defp rotate_current_player(game) do
    # how to remove function passed to find_index
    %{game | current_player: get_next_player(game, game.current_player)}
  end

  defp get_next_player(game, curr_player) do
    player_index = Enum.find_index(game.players, fn player -> player == curr_player end)
    new_curr_index = Integer.mod(player_index + 1, length(game.players))
    Enum.at(game.players, new_curr_index)
  end

  # region: notification
  def ask_current_player_to_play(%__MODULE__{} = game) do
    notify_current_player(game, :play)
  end

  def ask_current_player_to_bid(%__MODULE__{} = game) do
    notify_current_player(game, :bid)
  end

  defp notify_except(game, except_player, instruction) do
    Enum.reduce(game.players, game, fn player, game ->
      unless player == except_player,
        do: notify_player(game, player, instruction),
        else: game
    end)
  end

  defp notify_to_all(game, instruction) do
    Enum.reduce(game.players, game, fn player, game ->
      notify_player(game, player, instruction)
    end)
  end

  defp notify_current_player(game, instruction) do
    notify_player(game, game.current_player, instruction)
  end

  defp notify_player(game, player, instruction) do
    %__MODULE__{game | instructions: [{:notify_player, player, instruction} | game.instructions]}
  end

  defp notify_server(game, message) do
    %__MODULE__{game | instructions: [{:notify_server, message} | game.instructions]}
  end
end

# todo
# decide whether to use call or cast for player actions?
# manage leaving of players between game
# manage opponents posisiton in only one place

# instructions
# :bid
# {;bid, player, bid}
# {:dealer, dealer}
# {:dealer, dealer, cards}
