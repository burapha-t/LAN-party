defmodule LanParty.LiarsDice.ViewTest do
  use ExUnit.Case, async: true

  alias LanParty.LiarsDice.{Rules, View}

  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)

  defp game do
    game = Rules.new(["a", "b", "c"], %{}, roller: &fixed/1)
    %{game | dice: %{"a" => [2, 5], "b" => [1, 1, 3, 4, 6], "c" => []}, face: 4, roll: 3}
  end

  test "a phone sees only its own dice, the roll number and the face" do
    assert View.player_view(game(), "a") == %{dice: [2, 5], roll: 3, face: 4, out?: false}
  end

  test "a player with no dice is out" do
    assert View.player_view(game(), "c").out?
  end

  test "the table sees each player's dice count in seat order and the total, never a die's value" do
    assert View.table_view(game()) == %{
             counts: [{"a", 2}, {"b", 5}, {"c", 0}],
             total: 7,
             face: 4,
             roll: 3
           }
  end
end
