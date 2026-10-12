defmodule LanParty.Games do
  @moduledoc """
  The games on the table's "Select the game" screen (CLAUDE.md "Games"). A playable game names its
  rules module, which implements `LanParty.Game`. A list, not a framework.
  """

  # A playable game starts with 2 players unless it has a `min_players`.
  @games [
    %{id: :uno, name: "UNO", playable?: true, module: LanParty.Uno.Rules},
    %{id: :liars_dice, name: "Liar's Dice", playable?: true, module: LanParty.LiarsDice.Rules},
    %{
      id: :undercover,
      name: "Undercover",
      playable?: true,
      module: LanParty.Undercover.Rules,
      min_players: 3
    },
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

  @doc "How many seated players a game needs before the table can start it."
  def min_players(id), do: Enum.find_value(@games, 2, &(&1.id == id and &1[:min_players]))
end
