defmodule HandTest do
  use ExUnit.Case

  alias Callbreak.Hand, as: H

  @players [:a, :b, :c, :d]

  # hand doesn't check for turn so test it in game

  # setup do
  #  hand = H.start_new(players)
  #  [hand: hand]
  # end

  test "hand is initiated correctly" do
    assert {%H{hand_state: :bidding}, _} = H.start_new(@players)
  end
end
