defmodule LanParty.Uno.View do
  @moduledoc """
  What each screen may see of a game: a phone gets only its own hand, the table gets counts.
  The phone never draws the pile; `top` and `color` are there to word error messages.
  See docs/uno/design.md §6 "Views".
  """

  alias LanParty.Uno.{Card, Rules}

  def player_view(%Rules{} = game, token) do
    %{
      hand: Card.sort(Map.get(game.hands, token, [])),
      top: Rules.top_card(game),
      color: game.color,
      current: game.current,
      my_turn?: game.current == token,
      prompt: prompt(game, token),
      next: if(token in game.players, do: Rules.next_player(game, token)),
      others: Enum.reject(game.players, &(&1 == token)),
      counts: Map.new(game.hands, fn {player, cards} -> {player, length(cards)} end),
      seven_zero?: game.settings.seven_zero,
      stack_options: Rules.stack_options(game),
      last_played_by: game.last_played_by,
      last_challenge: game.last_challenge
    }
  end

  def table_view(%Rules{} = game) do
    %{
      top: Rules.top_card(game),
      color: game.color,
      draw_pile_size: length(game.draw_pile),
      direction: game.direction,
      counts: Enum.map(game.players, &{&1, length(game.hands[&1])}),
      current: game.current,
      pending_total: pending_total(game.pending),
      winner: game.winner
    }
  end

  defp prompt(%{pending: {:start_color, token}}, token), do: :choose_start_color

  defp prompt(%{pending: {:drawn, token, card_id}} = game, token),
    do: {:drawn, Enum.find(game.hands[token], &(&1.id == card_id))}

  defp prompt(%{pending: {:penalty, penalty}, current: token}, token),
    do: {:penalty, penalty.total, penalty.challenge != nil}

  defp prompt(_game, _token), do: nil

  defp pending_total({:penalty, %{total: total}}), do: total
  defp pending_total(_pending), do: 0
end
