defmodule Callbreak.Constants do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @trump_suit :spade
      @suites [:spade, :heart, :club, :diamond]
      @ranks [:ace, 2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king]

      @timer_in_sec 5
      @timer_in_msec @timer_in_sec * 1000

      @player_id_len 6
      @game_id_len 6

      @bot_delay_in_msec 5 * 1000
    end
  end
end
