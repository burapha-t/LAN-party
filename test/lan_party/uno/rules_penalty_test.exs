defmodule LanParty.Uno.RulesPenaltyTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.{Rules, View}

  defp play(game, token, id, opts \\ %{}), do: Rules.apply_action(game, token, {:play, id, opts})

  # "a" holds a red +2 (10), a +4 (11), a red 1 (1), a blue 9 (2).
  # "b" holds a green +2 (12), a +4 (13), a blue +2 (14), a green 3 (3).
  defp penalty_game(fields \\ []) do
    hands = %{
      "a" => [c(10, :red, :draw2), c(11, nil, :wild_draw4), c(1, :red, 1), c(2, :blue, 9)],
      "b" => [c(12, :green, :draw2), c(13, nil, :wild_draw4), c(14, :blue, :draw2), c(3, :green, 3)],
      "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]
    }

    game(Keyword.merge([hands: hands], fields))
  end

  # "a" holds no red card, so their +4 is legal.
  defp fair_plus4_game do
    penalty_game(hands: %{"a" => [c(11, nil, :wild_draw4), c(2, :blue, 9)], "b" => [c(3, :green, 3)], "c" => [c(5, :yellow, 6)]})
  end

  describe "+2" do
    test "puts a penalty on the next player" do
      {:ok, game} = play(penalty_game(), "a", 10)
      assert game.current == "b"
      assert game.pending == {:penalty, %{total: 2, top: :draw2, challenge: nil}}
    end

    test "the target must take it first" do
      {:ok, game} = play(penalty_game(), "a", 10)

      assert play(game, "b", 3) == {:error, :resolve_penalty}
      assert Rules.apply_action(game, "b", :draw) == {:error, :resolve_penalty}
      assert Rules.apply_action(game, "b", :challenge) == {:error, :not_now}
      assert Rules.apply_action(game, "c", :accept) == {:error, :not_your_turn}
    end

    test "accepting draws the total and loses the turn" do
      {:ok, game} = play(penalty_game(), "a", 10)
      {:ok, game} = Rules.apply_action(game, "b", :accept)

      assert length(game.hands["b"]) == 6
      assert game.current == "c"
      assert game.pending == nil
      refute game.jump_in_open
    end

    test "a winning +2 gives nobody a penalty" do
      {:ok, game} = play(penalty_game(hands: %{"a" => [c(10, :red, :draw2)], "b" => [c(3, :green, 3)], "c" => [c(5, :yellow, 6)]}), "a", 10)
      assert Rules.winner(game) == "a"
      assert game.pending == nil
    end

    test "accepting needs a penalty" do
      assert Rules.apply_action(penalty_game(), "a", :accept) == {:error, :not_now}
    end
  end

  describe "+4 and the challenge" do
    test "a +4 played while holding the current color is recorded as a bluff" do
      {:ok, game} = play(penalty_game(), "a", 11, %{color: :green})

      assert game.color == :green
      assert game.current == "b"
      assert game.pending == {:penalty, %{total: 4, top: :draw4, challenge: %{by: "a", legal: false, color: :red}}}
    end

    test "a +4 played without the current color is recorded as fair" do
      {:ok, game} = play(fair_plus4_game(), "a", 11, %{color: :green})
      assert {:penalty, %{challenge: %{legal: true}}} = game.pending
    end

    test "challenging a fair +4: the challenger draws 6 and loses the turn" do
      {:ok, game} = play(fair_plus4_game(), "a", 11, %{color: :green})
      {:ok, game} = Rules.apply_action(game, "b", :challenge)

      assert length(game.hands["b"]) == 7
      assert game.current == "c"
      assert game.pending == nil
      assert game.last_challenge == %{challenger: "b", by: "a", legal: true, color: :red}
    end

    test "challenging a bluff: the bluffer draws 4, the challenger plays on" do
      {:ok, game} = play(penalty_game(), "a", 11, %{color: :green})
      {:ok, game} = Rules.apply_action(game, "b", :challenge)

      assert length(game.hands["a"]) == 3 + 4
      assert length(game.hands["b"]) == 4
      assert game.current == "b"
      assert game.pending == nil
      assert game.color == :green
      assert game.last_challenge.legal == false

      {:ok, game} = play(game, "b", 3)
      assert game.last_challenge == nil
    end

    test "accepting a +4 draws 4 and loses the turn" do
      {:ok, game} = play(penalty_game(), "a", 11, %{color: :green})
      {:ok, game} = Rules.apply_action(game, "b", :accept)

      assert length(game.hands["b"]) == 8
      assert game.current == "c"
    end
  end

  describe "stacking" do
    test "off by default" do
      {:ok, game} = play(penalty_game(), "a", 10)
      assert play(game, "b", 12) == {:error, :resolve_penalty}
    end

    test "Stacking +2s: any +2 on a +2 passes the total on" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus2: true)), "a", 10)
      {:ok, game} = play(game, "b", 12)

      assert game.current == "c"
      assert game.pending == {:penalty, %{total: 4, top: :draw2, challenge: nil}}
    end

    test "Stacking +2s alone doesn't allow a +4 on a +2" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus2: true)), "a", 10)
      assert play(game, "b", 13, %{color: :red}) == {:error, :resolve_penalty}
    end

    test "Stacking +4s: a +4 on a +4 passes the total on and can't be challenged" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus4: true)), "a", 11, %{color: :blue})
      {:ok, game} = play(game, "b", 13, %{color: :yellow})

      assert game.current == "c"
      assert game.pending == {:penalty, %{total: 8, top: :draw4, challenge: nil}}
    end

    test "both on: a +4 on a +2" do
      both = settings(stack_plus2: true, stack_plus4: true)
      {:ok, game} = play(penalty_game(settings: both), "a", 10)
      {:ok, game} = play(game, "b", 13, %{color: :yellow})

      assert game.pending == {:penalty, %{total: 6, top: :draw4, challenge: nil}}
    end

    test "both on: a +2 on a +4 only in the chosen color" do
      both = settings(stack_plus2: true, stack_plus4: true)
      {:ok, game} = play(penalty_game(settings: both), "a", 11, %{color: :blue})

      assert play(game, "b", 12) == {:error, :resolve_penalty}
      {:ok, game} = play(game, "b", 14)
      assert game.pending == {:penalty, %{total: 6, top: :draw2, challenge: nil}}
    end

    test "the phone is told what it may do" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus4: true)), "a", 11, %{color: :blue})
      view = View.player_view(game, "b")

      assert view.prompt == {:penalty, 4, true}
      assert view.stack_options == [:wild_draw4]
      assert View.player_view(game, "c").prompt == nil
      assert Rules.stack_options(penalty_game()) == []
    end
  end
end
