defmodule LanParty.GamesTest do
  use ExUnit.Case, async: true

  alias LanParty.Games

  test "all 8 games from CLAUDE.md, in order; UNO and Liar's Dice are playable" do
    assert Enum.map(Games.all(), & &1.name) ==
             ["UNO", "Liar's Dice", "Quiplash", "Paranoia", "Who wrote it?", "Love Letter", "Never Have I Ever", "Killer"]

    assert Games.playable?(:uno)
    assert Games.playable?(:liars_dice)
    refute Games.playable?(:quiplash)
    refute Games.playable?(:chess)
    assert Games.name(:uno) == "UNO"
  end

  test "a playable game names its rules module" do
    assert Games.module(:uno) == LanParty.Uno.Rules
    assert Games.module(:liars_dice) == LanParty.LiarsDice.Rules
    assert Games.module(:quiplash) == nil
    assert Games.module(:chess) == nil
  end
end
