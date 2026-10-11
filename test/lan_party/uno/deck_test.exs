defmodule LanParty.Uno.DeckTest do
  use ExUnit.Case, async: true

  alias LanParty.Uno.{Card, Deck}

  test "the deck has the 108 official cards with unique ids" do
    deck = Deck.new()

    assert length(deck) == 108
    assert deck |> Enum.map(& &1.id) |> Enum.sort() == Enum.to_list(1..108)

    for color <- Card.colors() do
      cards = Enum.filter(deck, &(&1.color == color))
      assert length(cards) == 25
      assert Enum.count(cards, &(&1.value == 0)) == 1

      for value <- Enum.to_list(1..9) ++ [:skip, :reverse, :draw2] do
        assert Enum.count(cards, &(&1.value == value)) == 2
      end
    end

    assert Enum.count(deck, &(&1.value == :wild)) == 4
    assert Enum.count(deck, &(&1.value == :wild_draw4)) == 4
  end

  test "the order is fixed: red 0, red 1, red 2, ..., then yellow, green, blue, Wilds, +4s" do
    deck = Deck.new()

    assert Enum.take(deck, 3) == [
             %Card{id: 1, color: :red, value: 0},
             %Card{id: 2, color: :red, value: 1},
             %Card{id: 3, color: :red, value: 2}
           ]

    assert List.last(deck) == %Card{id: 108, color: nil, value: :wild_draw4}
  end

  test "shuffle keeps the same cards" do
    deck = Deck.new()
    assert Enum.sort_by(Deck.shuffle(deck), & &1.id) == deck
  end
end
