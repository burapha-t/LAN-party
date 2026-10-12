defmodule LanParty.GamesTest do
  use ExUnit.Case, async: true

  alias LanParty.Games

  test "all 9 games, in order; UNO, Liar's Dice and Undercover are playable" do
    assert Enum.map(Games.all(), & &1.name) ==
             [
               "UNO",
               "Liar's Dice",
               "Undercover",
               "Quiplash",
               "Paranoia",
               "Who wrote it?",
               "Love Letter",
               "Never Have I Ever",
               "Killer"
             ]

    assert Games.playable?(:uno)
    assert Games.playable?(:liars_dice)
    assert Games.playable?(:undercover)
    refute Games.playable?(:quiplash)
    refute Games.playable?(:chess)
    assert Games.name(:uno) == "UNO"
    assert Games.name(:undercover) == "Undercover"
  end

  test "a playable game names its rules module" do
    assert Games.module(:uno) == LanParty.Uno.Rules
    assert Games.module(:liars_dice) == LanParty.LiarsDice.Rules
    assert Games.module(:undercover) == LanParty.Undercover.Rules
    assert Games.module(:quiplash) == nil
    assert Games.module(:chess) == nil
  end

  test "a game starts with 2 players unless it says otherwise; Undercover needs 3" do
    assert Games.min_players(:uno) == 2
    assert Games.min_players(:liars_dice) == 2
    assert Games.min_players(:undercover) == 3
    assert Games.min_players(:chess) == 2
  end
end
