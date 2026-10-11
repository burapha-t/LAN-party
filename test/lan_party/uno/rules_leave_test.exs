defmodule LanParty.Uno.RulesLeaveTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.Rules

  describe "remove_player/2" do
    test "their cards go into the draw pile and play goes on" do
      game = Rules.remove_player(game(), "b")

      assert game.players == ["a", "c"]
      refute Map.has_key?(game.hands, "b")
      assert length(game.draw_pile) == 12
      assert game.current == "a"
    end

    test "if it was their turn, the turn passes" do
      assert Rules.remove_player(game(), "a").current == "b"
    end

    test "against the direction of play, the turn passes the other way" do
      assert Rules.remove_player(game(direction: -1), "a").current == "c"
    end

    test "a penalty aimed at them is dropped" do
      game = game(current: "b", pending: {:penalty, %{total: 4, top: :draw2, challenge: nil}})
      game = Rules.remove_player(game, "b")

      assert game.current == "c"
      assert game.pending == nil
    end

    test "if they had to pick the starting color, the next player picks it" do
      assert Rules.remove_player(game(pending: {:start_color, "a"}), "a").pending == {:start_color, "b"}
    end

    test "if they played the +4 being faced, the challenge goes away" do
      challenge = %{by: "a", legal: false, color: :red}
      game = game(current: "b", pending: {:penalty, %{total: 4, top: :draw4, challenge: challenge}})
      game = Rules.remove_player(game, "a")

      assert game.pending == {:penalty, %{total: 4, top: :draw4, challenge: nil}}
      assert game.current == "b"
    end

    test "removing someone who isn't in the round changes nothing" do
      assert Rules.remove_player(game(), "zed") == game()
    end
  end

  describe "draw_for/3" do
    test "the player draws n cards and nothing else changes" do
      game = game(current: "b", jump_in_open: true)
      {:ok, after_draw} = Rules.draw_for(game, "c", 3)

      assert length(after_draw.hands["c"]) == 5
      assert after_draw.current == "b"
      assert after_draw.pending == nil
      assert after_draw.jump_in_open
    end

    test "only players in the round" do
      assert Rules.draw_for(game(), "zed", 2) == {:error, :not_in_game}
    end

    test "when both piles run dry, they draw what there is" do
      game = game(draw_pile: [c(90, :green, 8), c(91, :green, 9)], discard: [c(100, :red, 5)])
      {:ok, game} = Rules.draw_for(game, "c", 10)

      assert length(game.hands["c"]) == 4
      assert game.draw_pile == []
    end
  end
end
