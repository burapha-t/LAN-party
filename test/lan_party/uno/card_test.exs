defmodule LanParty.Uno.CardTest do
  use ExUnit.Case, async: true

  alias LanParty.Uno.Card

  defp c(id, color, value), do: %Card{id: id, color: color, value: value}

  test "label/1 names a card for messages" do
    assert Card.label(c(1, :red, 7)) == "red 7"
    assert Card.label(c(2, :blue, :draw2)) == "blue +2"
    assert Card.label(c(3, :green, :skip)) == "green skip"
    assert Card.label(c(4, :yellow, :reverse)) == "yellow reverse"
    assert Card.label(c(5, nil, :wild)) == "Wild"
    assert Card.label(c(6, nil, :wild_draw4)) == "Wild +4"
  end

  test "wild?/1 is true only for Wild and +4" do
    assert Card.wild?(c(1, nil, :wild))
    assert Card.wild?(c(2, nil, :wild_draw4))
    refute Card.wild?(c(3, :red, :draw2))
  end

  test "sort/1 orders by color (red, yellow, green, blue, wilds), then numbers, Skip, Reverse, +2" do
    cards = [c(1, :blue, 3), c(2, nil, :wild), c(3, :red, :skip), c(4, :red, 2), c(5, :yellow, 0)]
    assert Enum.map(Card.sort(cards), & &1.id) == [4, 3, 5, 1, 2]
  end
end
