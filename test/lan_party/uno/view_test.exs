defmodule LanParty.Uno.ViewTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.View

  test "a phone sees its own hand, sorted, and only counts for everyone else" do
    game =
      game(
        hands: %{
          "a" => [c(1, :blue, 2), c(2, nil, :wild), c(3, :red, 9)],
          "b" => [c(4, :red, 1)],
          "c" => [c(5, :red, 2)]
        }
      )

    view = View.player_view(game, "a")

    assert Enum.map(view.hand, & &1.id) == [3, 1, 2]
    assert view.my_turn?
    assert view.current == "a"
    assert view.next == "b"
    assert view.others == ["b", "c"]
    assert view.counts == %{"a" => 3, "b" => 1, "c" => 1}
    refute Map.has_key?(view, :hands)
    refute view.seven_zero?
  end

  test "the first player is asked for the starting color; nobody else is" do
    game = game(pending: {:start_color, "a"})
    assert View.player_view(game, "a").prompt == :choose_start_color
    assert View.player_view(game, "b").prompt == nil
  end

  test "the table sees counts in seat order, the pile, and the pending total" do
    view = View.table_view(game(pending: {:penalty, %{total: 6, top: :draw2, challenge: nil}}, current: "b"))

    assert view.counts == [{"a", 2}, {"b", 2}, {"c", 2}]
    assert view.top.id == 100
    assert view.color == :red
    assert view.draw_pile_size == 10
    assert view.pending_total == 6
    assert view.current == "b"
    assert view.direction == 1
  end
end
