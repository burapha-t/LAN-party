defmodule LanParty.Games do
  @moduledoc """
  The games on the table's "Select the game" screen (CLAUDE.md "Games"). A playable game names its
  rules module, which implements `LanParty.Game`. A list, not a framework.
  """

  @games [
    %{id: :uno, name: "UNO", playable?: true, module: LanParty.Uno.Rules},
    %{id: :liars_dice, name: "Liar's Dice", playable?: true, module: LanParty.LiarsDice.Rules},
    %{id: :quiplash, name: "Quiplash", playable?: false},
    %{id: :paranoia, name: "Paranoia", playable?: false},
    %{id: :who_wrote_it, name: "Who wrote it?", playable?: false},
    %{id: :love_letter, name: "Love Letter", playable?: false},
    %{id: :never_have_i_ever, name: "Never Have I Ever", playable?: false},
    %{id: :killer, name: "Killer", playable?: false}
  ]

  def all, do: @games

  def playable?(id), do: Enum.any?(@games, &(&1.id == id and &1.playable?))

  def name(id), do: Enum.find_value(@games, &(&1.id == id and &1.name))

  @doc "The rules module of a playable game, or nil."
  def module(id), do: Enum.find_value(@games, &(&1.id == id and &1[:module]))
end
