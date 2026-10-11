defmodule LanParty.Uno.RulesPlayTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.Rules

  defp play(game, token, id, opts \\ %{}), do: Rules.apply_action(game, token, {:play, id, opts})

  defp hands_with_a(cards) do
    %{"a" => cards, "b" => [c(3, :green, 3), c(4, :green, 4)], "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]}
  end

  describe "playing a card" do
    test "a card of the current color goes on the pile and the turn passes" do
      {:ok, game} = play(game(), "a", 1)

      assert Rules.top_card(game).id == 1
      assert ids(game.hands["a"]) == [2]
      assert game.current == "b"
      assert game.color == :red
      assert game.jump_in_open
      assert game.last_played_by == "a"
    end

    test "a card with the same value matches and changes the color" do
      {:ok, game} = play(game(hands: hands_with_a([c(7, :blue, 5), c(2, :blue, 9)])), "a", 7)
      assert game.color == :blue
    end

    test "a card that matches neither color nor value is rejected" do
      assert play(game(), "a", 2) == {:error, :does_not_match}
    end

    test "only the current player can play" do
      assert play(game(), "b", 3) == {:error, :not_your_turn}
    end

    test "you can only play a card you hold" do
      assert play(game(), "a", 3) == {:error, :not_in_hand}
      assert play(game(), "a", "1") == {:error, :not_in_hand}
    end

    test "a double tap is rejected the second time" do
      {:ok, game} = play(game(), "a", 1)
      assert {:error, _reason} = play(game, "a", 1)
    end

    test "Skip skips the next player" do
      {:ok, game} = play(game(hands: hands_with_a([c(7, :red, :skip), c(2, :blue, 9)])), "a", 7)
      assert game.current == "c"
    end

    test "Reverse flips the direction" do
      {:ok, game} = play(game(hands: hands_with_a([c(7, :red, :reverse), c(2, :blue, 9)])), "a", 7)
      assert game.direction == -1
      assert game.current == "c"
    end

    test "with two players Reverse acts as Skip" do
      game = game(players: ["a", "b"], hands: %{"a" => [c(7, :red, :reverse), c(2, :blue, 9)], "b" => [c(3, :green, 3)]})
      {:ok, game} = play(game, "a", 7)
      assert game.current == "a"
    end

    test "a Wild needs one of the four colors and sets it" do
      game = game(hands: hands_with_a([c(7, nil, :wild), c(2, :blue, 9)]))

      assert play(game, "a", 7) == {:error, :choose_color}
      assert play(game, "a", 7, %{color: :purple}) == {:error, :choose_color}

      {:ok, game} = play(game, "a", 7, %{color: :green})
      assert game.color == :green
      assert game.current == "b"
    end

    test "emptying your hand wins at once" do
      {:ok, game} = play(game(hands: hands_with_a([c(1, :red, 1)])), "a", 1)

      assert Rules.winner(game) == "a"
      assert Rules.apply_action(game, "b", :draw) == {:error, :game_over}
    end

    test "you can't play while the starting color is still to be picked" do
      game = game(pending: {:start_color, "a"}, discard: [c(100, nil, :wild)], color: nil)
      assert play(game, "a", 1) == {:error, :choose_start_color}
    end
  end

  describe "drawing" do
    test "an unplayable card is kept and the turn passes, even if you held a playable card" do
      {:ok, game} = Rules.apply_action(game(), "a", :draw)

      assert ids(game.hands["a"]) == [1, 2, 201]
      assert game.current == "b"
      refute game.jump_in_open
    end

    test "a playable card can be played or kept, and nothing else" do
      {:ok, drawn} = Rules.apply_action(game(draw_pile: [c(90, :red, 8) | pile(3)]), "a", :draw)
      assert drawn.pending == {:drawn, "a", 90}
      assert drawn.current == "a"

      assert play(drawn, "a", 1) == {:error, :play_drawn_or_keep}
      assert Rules.apply_action(drawn, "a", :draw) == {:error, :play_drawn_or_keep}

      {:ok, kept} = Rules.apply_action(drawn, "a", :keep)
      assert kept.current == "b"
      assert kept.pending == nil

      {:ok, played} = play(drawn, "a", 90)
      assert Rules.top_card(played).id == 90
      assert played.current == "b"
      assert played.pending == nil
    end

    test "you can only draw on your turn" do
      assert Rules.apply_action(game(), "b", :draw) == {:error, :not_your_turn}
    end

    test "keeping needs a drawn card" do
      assert Rules.apply_action(game(), "a", :keep) == {:error, :not_now}
    end

    test "an empty draw pile is refilled from the discard pile, keeping its top card" do
      game = game(draw_pile: [], discard: [c(100, :red, 5), c(101, :green, 7), c(102, :blue, 1)])
      {:ok, game} = Rules.apply_action(game, "a", :draw)

      assert length(game.hands["a"]) == 3
      assert Enum.map(game.discard, & &1.id) == [100]
      assert length(game.draw_pile) == 1
    end

    test "with both piles empty nothing is drawn and the turn passes" do
      {:ok, game} = Rules.apply_action(game(draw_pile: [], discard: [c(100, :red, 5)]), "a", :draw)

      assert ids(game.hands["a"]) == [1, 2]
      assert game.current == "b"
    end
  end
end
