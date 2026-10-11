defmodule LanParty.UnoHelpers do
  @moduledoc "Builders for deterministic UNO games in tests."

  alias LanParty.Uno.{Card, Deck, Rules}

  def c(id, color, value), do: %Card{id: id, color: color, value: value}

  @doc """
  A game in progress, built field by field. Defaults: players a, b, c; "a" to play; red 5 on the
  pile; the jump-in window open (a card was just played); a draw pile of green cards that never
  match red 5.
  """
  def game(fields \\ []) do
    defaults = [
      players: ["a", "b", "c"],
      hands: %{
        "a" => [c(1, :red, 1), c(2, :blue, 9)],
        "b" => [c(3, :green, 3), c(4, :green, 4)],
        "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]
      },
      draw_pile: pile(10),
      discard: [c(100, :red, 5)],
      color: :red,
      current: "a",
      direction: 1,
      settings: Rules.default_settings(),
      jump_in_open: true
    ]

    struct!(Rules, Keyword.merge(defaults, fields))
  end

  @doc "n green number cards (ids 201..), never a 5."
  def pile(n) do
    values = [1, 2, 3, 4, 6, 7, 8, 9]
    for i <- 1..n, do: c(200 + i, :green, Enum.at(values, rem(i - 1, length(values))))
  end

  def settings(overrides), do: Map.merge(Rules.default_settings(), Map.new(overrides))

  def ids(cards), do: cards |> Enum.map(& &1.id) |> Enum.sort()

  @doc "The ordered deck, rearranged so the starting card (dealt after the hands) has `value`."
  def deck_starting_with(player_count, value) do
    deck = Deck.new()
    start = Enum.find(deck, &(&1.value == value))
    {hands, rest} = deck |> List.delete(start) |> Enum.split(7 * player_count)
    hands ++ [start | rest]
  end

  @doc "Waits until each view has handled every message already queued for it (e.g. a Room broadcast), so the next render isn't stale."
  def sync(views) when is_list(views) do
    Enum.each(views, &sync/1)
    views
  end

  def sync(%Phoenix.LiveViewTest.View{pid: pid} = view) do
    _ = :sys.get_state(pid)
    view
  end

  @doc "Gives LiveView tests a fresh app-wide Room."
  def restart_room do
    :ok = Supervisor.terminate_child(LanParty.Supervisor, LanParty.Room)
    {:ok, _pid} = Supervisor.restart_child(LanParty.Supervisor, LanParty.Room)
    :ok
  end
end
