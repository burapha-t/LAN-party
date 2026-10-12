defmodule LanParty.LiarsDice.RulesTest do
  use ExUnit.Case, async: true

  alias LanParty.LiarsDice.Rules

  # A fixed "roll": the first n of these values. Five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp all_twos(n), do: List.duplicate(2, n)

  defp game, do: Rules.new(["a", "b", "c"], %{}, roller: &fixed/1)
  defp with_dice(game, dice), do: %{game | dice: Map.merge(game.dice, dice)}

  describe "new/3" do
    test "everyone gets 5 dice, sorted low to high; roll 1, no face, no winner" do
      game = game()

      assert game.players == ["a", "b", "c"]

      assert game.dice == %{
               "a" => [1, 1, 3, 4, 6],
               "b" => [1, 1, 3, 4, 6],
               "c" => [1, 1, 3, 4, 6]
             }

      assert game.roll == 1
      assert game.face == nil
      assert Rules.winner(game) == nil
    end

    test "settings are ignored, and the default roller rolls real dice" do
      game = Rules.new(["a", "b"], %{stack_plus2: true}, [])

      for {_token, dice} <- game.dice do
        assert length(dice) == 5
        assert dice == Enum.sort(dice)
        assert Enum.all?(dice, &(&1 in 1..6))
      end
    end

    test "random_dice/1 rolls n dice from 1 to 6" do
      assert Rules.random_dice(0) == []
      dice = Rules.random_dice(200)
      assert length(dice) == 200
      assert Enum.all?(dice, &(&1 in 1..6))
    end
  end

  describe "rolling" do
    test "players with dice re-roll as many as they have; out players stay out; the roll goes up; the face clears" do
      game = game() |> with_dice(%{"b" => [2, 5], "c" => []})
      game = %{game | face: 4, roller: &all_twos/1}

      assert {:ok, rolled} = Rules.table_action(game, :roll)
      assert rolled.dice == %{"a" => [2, 2, 2, 2, 2], "b" => [2, 2], "c" => []}
      assert rolled.roll == 2
      assert rolled.face == nil
    end
  end

  describe "counting" do
    test "the face can be 2 to 6" do
      for face <- 2..6 do
        assert {:ok, %{face: ^face}} = Rules.table_action(game(), {:count, face})
      end
    end

    test "1s are wild, so 1 can't be counted; nor can 7 or junk" do
      for face <- [1, 7, 0, "4", nil] do
        assert Rules.table_action(game(), {:count, face}) == {:error, :bad_face}
      end
    end
  end

  describe "taking a die" do
    test "the player loses their highest die; the others keep theirs" do
      assert {:ok, game} = Rules.table_action(game(), {:take_die, "a"})
      assert game.dice["a"] == [1, 1, 3, 4]
      assert game.dice["b"] == [1, 1, 3, 4, 6]
      assert Rules.winner(game) == nil
    end

    test "it changes neither the roll nor the face" do
      game = %{game() | face: 4}
      assert {:ok, %{face: 4, roll: 1}} = Rules.table_action(game, {:take_die, "a"})
    end

    test "taking the last die puts the player out, but keeps their seat" do
      game = game() |> with_dice(%{"a" => [3]})

      assert {:ok, game} = Rules.table_action(game, {:take_die, "a"})
      assert game.dice["a"] == []
      assert "a" in game.players
      assert Rules.winner(game) == nil
    end

    test "when only one player has dice left, they win" do
      game = game() |> with_dice(%{"a" => [3], "c" => []})

      assert {:ok, game} = Rules.table_action(game, {:take_die, "a"})
      assert Rules.winner(game) == "b"
    end

    test "unknown players and players with no dice are refused" do
      assert Rules.table_action(game(), {:take_die, "zed"}) == {:error, :not_in_game}

      game = game() |> with_dice(%{"c" => []})
      assert Rules.table_action(game, {:take_die, "c"}) == {:error, :no_dice}
    end
  end

  describe "remove_player/2" do
    test "a kicked player's dice leave the game" do
      game = Rules.remove_player(game(), "b")

      assert game.players == ["a", "c"]
      refute Map.has_key?(game.dice, "b")
      assert Rules.winner(game) == nil
    end

    test "if only one player with dice is left, they win" do
      game = game() |> with_dice(%{"c" => []}) |> Rules.remove_player("b")
      assert Rules.winner(game) == "a"
    end

    test "removing an out player doesn't end the game" do
      game = game() |> with_dice(%{"c" => []}) |> Rules.remove_player("c")

      assert game.players == ["a", "b"]
      assert Rules.winner(game) == nil
    end
  end

  test "phones have no moves" do
    assert Rules.apply_action(game(), "a", :roll) == {:error, :no_actions}
  end

  test "a table action Liar's Dice doesn't know is refused" do
    assert Rules.table_action(game(), {:draw_for, "a", 2}) == {:error, :unknown_action}
  end
end
