defmodule Callbreak.Constants do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @trump_suit :spade
      @suites [:spade, :heart, :club, :diamond]
      @ranks [:ace, 2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king]
    end
  end
end
