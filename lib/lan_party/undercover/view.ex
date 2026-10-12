defmodule LanParty.Undercover.View do
  @moduledoc """
  What each screen may see of an Undercover game: a phone gets its own word and how many undercovers
  were dealt, never its role; the table gets who is playing and the count, never a word.
  See docs/undercover/README.md "Views".
  """

  alias LanParty.Undercover.Rules

  def player_view(%Rules{} = game, token),
    do: %{word: Map.get(game.words, token), deal: game.deal, undercovers: game.undercovers}

  def table_view(%Rules{} = game),
    do: %{players: game.players, deal: game.deal, undercovers: game.undercovers}
end
