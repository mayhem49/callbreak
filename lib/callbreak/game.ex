defmodule Callbreak.Game do
  alias Callbreak.Hand

  # defstruct [ # list of all players :players, player whose turn is it to play :current_player, each 4 sequence of cards played is one hand :current_hand, total 5 rounds but round that is being played currently :current_round, points scored in previous round :scorecard, :hand_count, current :round_count, instructions to be sent to players :instructions ]

  defstruct [
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

  def new([_, _, _, _] = players) do
    game = %__MODULE__{
      players: players,
      instructions: [],
      scorecard: [],
      dealer: Enum.random(players)
    }

    game
    |> notify_opponents_to_all()
    |> new_hand()
    |> return_instructions_and_game()
  end

  def new_hand(game) do
    # below code means:
    # randomly chose dealer in `new` will be shifted by one
    dealer = get_next_player(game, game.dealer)
    current_player = get_next_player(game, dealer)

    %{game | current_hand: Hand.new(), dealer: dealer, current_player: current_player}
    |> notify_dealer_to_all()
    |> deal()
    |> ask_current_player_to_bid()
  end

  # todo check turn
  def handle_bid(game, player, bid) do
    case Hand.take_bid(game.current_hand, player, bid) do
      {:ok, hand} ->
        game
        |> Map.put(:current_hand, hand)
        |> notify_player(player, {:bid_success, bid})
        |> notify_except(player, {:bid, player, bid})
        |> rotate_current_player()
        |> then(fn game ->
          if Hand.is_bidding_completed?(hand),
            do: ask_current_player_to_play(game),
            else: ask_current_player_to_bid(game)
        end)
        |> return_instructions_and_game()

      {:error, err_msg} ->
        game
        |> notify_player(player, err_msg)
        |> return_instructions_and_game()
    end
  end

  # todo check turn
  def handle_play(game, player, play_card) do
    case Hand.play(game.current_hand, player, play_card) do
      {:ok, hand, winner} ->
        game
        |> Map.put(:current_hand, hand)
        |> notify_player(player, {:play_success, play_card})
        |> notify_except(player, {:play, player, play_card})
        |> handle_trick_completion(winner)
        |> return_instructions_and_game()

      {:error, err_msg} ->
        game
        |> notify_player(player, err_msg)
        |> return_instructions_and_game()
    end
  end

  # handle current trick completion
  # it cascades to `check_hand_completion`
  # which cascades to `check_game_completion`
  def handle_trick_completion(game, nil) do
    game
    |> rotate_current_player()
    |> ask_current_player_to_play()
  end

  def handle_trick_completion(game, winner) do
    game
    |> Map.put(:current_player, winner)
    |> notify_to_all({:trick_winner, winner})
    |> check_hand_completion()
  end

  def check_hand_completion(game) do
    case Hand.maybe_hand_completed(game.current_hand) do
      nil ->
        ask_current_player_to_play(game)

      scorecard ->
        %{game | scorecard: [scorecard | game.scorecard]}
        |> notify_to_all({:scorecard, scorecard})
        |> check_game_completion()
    end
  end

  def check_game_completion(game) do
    if Enum.count(game.scorecard) == 5 do
      game
      # TODO: calculate points
      |> notify_to_all({:winner, "random player for now"})
      |> notify_to_all({:game_completed})
    else
      game
      |> new_hand()
    end
  end

  def return_instructions_and_game(game) do
    {Enum.reverse(game.instructions), %{game | instructions: []}}
  end

  def deal(game = %__MODULE__{}) do
    {hand, cards} = Hand.deal(game.current_hand, game.players)

    Enum.reduce(cards, %{game | current_hand: hand}, fn {player, cards}, acc_game ->
      notify_player(acc_game, player, {:cards, cards})
    end)
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
    notify_current_player(game, {:play})
  end

  def ask_current_player_to_bid(%__MODULE__{} = game) do
    notify_current_player(game, {:bid})
  end

  defp notify_opponents_to_all(game) do
    Enum.reduce(game.players, game, fn player, game ->
      opponents = List.delete(game.players, player)
      notify_player(game, player, {:opponents, opponents})
    end)
  end

  defp notify_dealer_to_all(game) do
    game
    |> notify_player(game.dealer, {:dealer, :self})
    |> notify_except(game.dealer, {:dealer, game.dealer})
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
end
