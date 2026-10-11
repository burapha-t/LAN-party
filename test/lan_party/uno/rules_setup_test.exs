defmodule LanParty.Uno.RulesSetupTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.{Card, Deck, Rules}

  describe "new/3" do
    test "deals 7 cards each and flips the first card" do
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, 5), first_player: "a")

      assert ids(game.hands["a"]) == [1, 2, 3, 4, 5, 7, 8]
      assert length(game.hands["b"]) == 7
      assert %Card{id: 6, value: 5, color: :red} = Rules.top_card(game)
      assert game.color == :red
      assert length(game.draw_pile) == 108 - 14 - 1
      assert game.current == "a"
      assert game.direction == 1
      assert game.pending == nil
      refute game.jump_in_open
    end

    test "a +4 can't start the game; it goes to the bottom of the draw pile" do
      plus4 = Enum.find(Deck.new(), &(&1.value == :wild_draw4))
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, :wild_draw4), first_player: "a")

      refute Rules.top_card(game).value == :wild_draw4
      assert List.last(game.draw_pile).id == plus4.id
      assert length(game.draw_pile) == 108 - 14 - 1
    end

    test "a starting Skip skips the first player" do
      game = Rules.new(["a", "b", "c"], %{}, deck: deck_starting_with(3, :skip), first_player: "a")
      assert game.current == "b"
    end

    test "a starting Reverse flips the direction; the first player still starts" do
      game = Rules.new(["a", "b", "c"], %{}, deck: deck_starting_with(3, :reverse), first_player: "a")
      assert game.direction == -1
      assert game.current == "a"
    end

    test "a starting +2 is a penalty for the first player" do
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, :draw2), first_player: "a")
      assert game.current == "a"
      assert game.pending == {:penalty, %{total: 2, top: :draw2, challenge: nil}}
    end

    test "a starting Wild makes the first player pick the color" do
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, :wild), first_player: "a")
      assert game.pending == {:start_color, "a"}
      assert game.color == nil
    end

    test "a starting 7 has no effect, even under 7-0" do
      game = Rules.new(["a", "b"], %{seven_zero: true}, deck: deck_starting_with(2, 7), first_player: "a")
      assert game.current == "a"
      assert game.pending == nil
    end

    test "settings are merged over the defaults" do
      game = Rules.new(["a", "b"], %{jump_in: true}, first_player: "a")
      assert game.settings.jump_in
      refute game.settings.stack_plus2
    end
  end

  describe "choosing the starting color" do
    setup do
      %{game: game(pending: {:start_color, "a"}, color: nil, discard: [c(100, nil, :wild)], jump_in_open: false)}
    end

    test "the first player picks it", %{game: game} do
      assert {:ok, game} = Rules.apply_action(game, "a", {:choose_color, :blue})
      assert game.color == :blue
      assert game.pending == nil
      assert game.current == "a"
    end

    test "nobody else can", %{game: game} do
      assert Rules.apply_action(game, "b", {:choose_color, :blue}) == {:error, :not_now}
    end

    test "only the four colors", %{game: game} do
      assert Rules.apply_action(game, "a", {:choose_color, :purple}) == {:error, :invalid_color}
    end
  end

  describe "apply_action/3" do
    test "rejects someone who isn't in the round" do
      assert Rules.apply_action(game(), "zed", :draw) == {:error, :not_in_game}
    end

    test "rejects everything once there is a winner" do
      assert Rules.apply_action(game(winner: "b"), "a", :draw) == {:error, :game_over}
    end

    test "rejects unknown actions" do
      assert Rules.apply_action(game(), "a", :dance) == {:error, :unknown_action}
    end
  end

  test "next_player/2 follows the direction of play" do
    assert Rules.next_player(game(), "c") == "a"
    assert Rules.next_player(game(direction: -1), "a") == "c"
  end
end
