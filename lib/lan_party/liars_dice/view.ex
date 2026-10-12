defmodule LanParty.LiarsDice.View do
  @moduledoc """
  What each screen may see of a Liar's Dice game: a phone gets only its own dice; the table gets the
  counts and the total, never a die's value. See docs/liars-dice/design.md §4 "Views".
  """

  alias LanParty.LiarsDice.Rules

  def player_view(%Rules{} = game, token) do
    dice = Map.get(game.dice, token, [])
    %{dice: dice, roll: game.roll, face: game.face, out?: dice == []}
  end

  def table_view(%Rules{} = game) do
    counts = Enum.map(game.players, &{&1, length(Map.get(game.dice, &1, []))})

    %{
      counts: counts,
      total: counts |> Enum.map(&elem(&1, 1)) |> Enum.sum(),
      face: game.face,
      roll: game.roll
    }
  end
end
