defmodule LanParty.Undercover.ViewTest do
  use ExUnit.Case, async: true

  alias LanParty.Undercover.{Rules, View}

  defp game do
    Rules.new(["a", "b", "c"], %{}, pairs: [{"Alpha", "Beta"}, {"Cedar", "Dune"}], shuffle: & &1)
  end

  test "a phone sees its own word, the deal number and how many undercovers there are" do
    assert View.player_view(game(), "a") == %{word: "Beta", deal: 1, undercovers: 1}
    assert View.player_view(game(), "b") == %{word: "Alpha", deal: 1, undercovers: 1}
  end

  test "a phone sees nothing else: no role, and no word but its own" do
    for token <- ["a", "b", "c"] do
      view = View.player_view(game(), token)

      others =
        game().words |> Map.delete(token) |> Map.values() |> Enum.reject(&(&1 == view.word))

      assert view |> Map.keys() |> Enum.sort() == [:deal, :undercovers, :word]
      assert others |> Enum.map(&(inspect(view) =~ &1)) |> Enum.all?(&(&1 == false))
    end
  end

  test "a player who isn't in the game has no word" do
    assert View.player_view(game(), "zed").word == nil
  end

  test "the table sees who is playing in seat order, the deal and the undercover count, and no word" do
    view = View.table_view(game())

    assert view == %{players: ["a", "b", "c"], deal: 1, undercovers: 1}
    refute inspect(view) =~ "Alpha"
    refute inspect(view) =~ "Beta"
  end

  test "after a kick the table still shows the count that was dealt" do
    game =
      Rules.new(["a", "b", "c", "d", "e", "f"], %{}, pairs: [{"Alpha", "Beta"}], shuffle: & &1)

    view = game |> Rules.remove_player("a") |> View.table_view()

    assert view.players == ["b", "c", "d", "e", "f"]
    assert view.undercovers == 2
  end
end
