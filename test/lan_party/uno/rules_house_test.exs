defmodule LanParty.Uno.RulesHouseTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.Rules

  defp play(game, token, id, opts \\ %{}), do: Rules.apply_action(game, token, {:play, id, opts})

  # 7-0 on; "a" holds a red 7 (7), a red 0 (8) and a blue 9 (2).
  defp seven_zero_game(fields \\ []) do
    hands = %{
      "a" => [c(7, :red, 7), c(8, :red, 0), c(2, :blue, 9)],
      "b" => [c(3, :green, 3)],
      "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]
    }

    game(Keyword.merge([settings: settings(seven_zero: true), hands: hands], fields))
  end

  # Jump-in on; players a–d; a red 5 was just played and "b" is to play.
  defp jump_game(fields \\ []) do
    hands = %{
      "a" => [c(1, :red, 1), c(2, :blue, 9)],
      "b" => [c(3, :green, 3), c(4, :green, 4)],
      "c" => [c(20, :red, 5), c(21, :red, 6), c(22, :red, :draw2)],
      "d" => [c(30, :red, :skip), c(31, :red, :draw2), c(32, :yellow, 8)]
    }

    game(Keyword.merge([players: ["a", "b", "c", "d"], current: "b", settings: settings(jump_in: true), hands: hands], fields))
  end

  describe "7-0" do
    test "a 7 needs another player in the round to swap with" do
      assert play(seven_zero_game(), "a", 7) == {:error, :choose_player}
      assert play(seven_zero_game(), "a", 7, %{swap_with: "a"}) == {:error, :choose_player}
      assert play(seven_zero_game(), "a", 7, %{swap_with: "zed"}) == {:error, :choose_player}
    end

    test "a 7 swaps hands with the chosen player" do
      {:ok, game} = play(seven_zero_game(), "a", 7, %{swap_with: "c"})

      assert ids(game.hands["a"]) == [5, 6]
      assert ids(game.hands["c"]) == [2, 8]
      assert game.current == "b"
    end

    test "a 0 passes every hand one seat in the direction of play" do
      {:ok, game} = play(seven_zero_game(), "a", 8)

      assert ids(game.hands["b"]) == [2, 7]
      assert ids(game.hands["c"]) == [3]
      assert ids(game.hands["a"]) == [5, 6]
      assert game.current == "b"
    end

    test "against the direction of play, hands go the other way" do
      {:ok, game} = play(seven_zero_game(direction: -1), "a", 8)

      assert ids(game.hands["c"]) == [2, 7]
      assert game.current == "c"
    end

    test "with 7-0 off, 7 and 0 are plain numbers" do
      {:ok, game} = play(seven_zero_game(settings: settings([])), "a", 7)
      assert ids(game.hands["a"]) == [2, 8]
    end

    test "a winning 7 doesn't swap" do
      game = seven_zero_game(hands: %{"a" => [c(7, :red, 7)], "b" => [c(3, :green, 3)], "c" => [c(5, :yellow, 6)]})
      {:ok, game} = play(game, "a", 7, %{swap_with: "b"})

      assert Rules.winner(game) == "a"
      assert ids(game.hands["b"]) == [3]
    end
  end

  describe "jump-in" do
    test "anyone can play an identical card out of turn; play continues from them" do
      {:ok, game} = play(jump_game(), "c", 20)

      assert Rules.top_card(game).id == 20
      assert game.current == "d"
      assert game.last_played_by == "c"
    end

    test "only when the house rule is on" do
      assert play(jump_game(settings: settings([])), "c", 20) == {:error, :not_your_turn}
    end

    test "only an identical card" do
      assert play(jump_game(), "c", 21) == {:error, :not_your_turn}
    end

    test "not after someone has drawn" do
      assert play(jump_game(jump_in_open: false), "c", 20) == {:error, :not_your_turn}
    end

    test "never on a Wild" do
      assert play(jump_game(discard: [c(100, nil, :wild)]), "c", 20) == {:error, :not_your_turn}
    end

    test "a jumped-in Skip skips the player after the jumper" do
      {:ok, game} = play(jump_game(discard: [c(100, :red, :skip)], current: "c"), "d", 30)
      assert game.current == "b"
    end

    test "a +2 jumped onto a pending +2 adds up, even with stacking off; the target is spared" do
      game = jump_game(discard: [c(100, :red, :draw2)], pending: {:penalty, %{total: 2, top: :draw2, challenge: nil}})
      {:ok, game} = play(game, "c", 22)

      assert game.current == "d"
      assert game.pending == {:penalty, %{total: 4, top: :draw2, challenge: nil}}
      assert ids(game.hands["b"]) == [3, 4]
    end

    test "the target can escape with an identical +2, even with stacking off" do
      hands = %{"a" => [c(1, :red, 1)], "b" => [c(40, :red, :draw2), c(3, :green, 3)], "c" => [c(21, :red, 6)], "d" => [c(32, :yellow, 8)]}
      game = jump_game(hands: hands, discard: [c(100, :red, :draw2)], pending: {:penalty, %{total: 2, top: :draw2, challenge: nil}})
      {:ok, game} = play(game, "b", 40)

      assert game.current == "c"
      assert game.pending == {:penalty, %{total: 4, top: :draw2, challenge: nil}}
    end

    test "jumping in with your last card wins" do
      hands = %{"a" => [c(1, :red, 1)], "b" => [c(3, :green, 3)], "c" => [c(20, :red, 5)], "d" => [c(32, :yellow, 8)]}
      {:ok, game} = play(jump_game(hands: hands), "c", 20)

      assert Rules.winner(game) == "c"
    end
  end
end
