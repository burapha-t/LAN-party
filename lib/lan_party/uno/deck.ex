defmodule LanParty.Uno.Deck do
  @moduledoc """
  The official 108-card deck: per color one 0 and two each of 1–9, Skip, Reverse and +2; plus 4 Wild
  and 4 +4. `new/0` returns a fixed order (tests rely on it); `shuffle/1` randomizes it.
  """

  alias LanParty.Uno.Card

  def new do
    twice = Enum.to_list(1..9) ++ [:skip, :reverse, :draw2]
    colored = for color <- Card.colors(), value <- [0] ++ twice ++ twice, do: {color, value}
    wilds = List.duplicate({nil, :wild}, 4) ++ List.duplicate({nil, :wild_draw4}, 4)

    (colored ++ wilds)
    |> Enum.with_index(1)
    |> Enum.map(fn {{color, value}, id} -> %Card{id: id, color: color, value: value} end)
  end

  def shuffle(cards), do: Enum.shuffle(cards)
end
