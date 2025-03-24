defmodule Callbreak.Constants do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @trump_suit :spade
      @suites [:spade, :heart, :club, :diamond]
      @ranks [:ace, 2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king]

      @allowed_move_time 20
      @allowed_move_time_ms @allowed_move_time * 1000

      @player_id_len 6
      @game_id_len 6

      @bot_delay_in_msec 5 * 1000

      @autoplay true
    end
  end
end
