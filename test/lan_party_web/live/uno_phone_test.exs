defmodule LanPartyWeb.UnoPhoneTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room
  alias LanParty.Uno.Rules

  # Erin (this phone) and Bob. With the fixed deck Erin holds red 0, 1, 2, 3, 4, 6, 7
  # (ids 1, 2, 3, 4, 5, 7, 8), Bob holds ids 9–15, red 5 starts the pile, and Erin goes first.
  setup %{conn: conn} do
    restart_room()
    use_deck(deck_starting_with(2, 5))
    {:ok, erin, _html} = live(phone(conn, "erin"), ~p"/")
    erin |> form("#join", %{name: "Erin"}) |> render_submit()
    :ok = Room.join("bob", "Bob", page())
    :ok = Room.pick_game(:uno)
    sync(erin)
    %{erin: erin}
  end

  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)
  defp use_deck(deck), do: :sys.replace_state(Room, &%{&1 | game_opts: [deck: deck, first_player: "erin"]})
  defp start!, do: :ok = Room.start_game()
  defp tap_card(view, id), do: view |> element(~s(.hand a.card[phx-value-id="#{id}"])) |> render_click()

  # Change the running game behind the scenes, then let the phone re-render.
  defp tweak_game(view, fun) do
    :sys.replace_state(Room, fn state -> %{state | game: fun.(state.game)} end)
    send(view.pid, {:party_updated, Room.get_state()})
    sync(view)
  end

  defp facing_plus4(game) do
    challenge = %{by: "bob", legal: true, color: :red}

    %{
      game
      | pending: {:penalty, %{total: 4, top: :draw4, challenge: challenge}},
        last_played_by: "bob",
        discard: [c(500, nil, :wild_draw4) | game.discard],
        color: :green
    }
  end

  test "the lobby lists the players", %{erin: erin} do
    assert has_element?(erin, ".brand", "UNO")
    assert has_element?(erin, ".wait", "Waiting for the table to start")
    assert has_element?(erin, ".people li.you", "Erin (you)")
    assert has_element?(erin, ".people li", "Bob")
  end

  test "a phone shows only its own hand, never the pile or the color", %{erin: erin} do
    start!()
    sync(erin)

    for id <- [1, 2, 3, 4, 5, 7, 8], do: assert(has_element?(erin, ~s(.hand a.card[phx-value-id="#{id}"])))
    for id <- 9..15, do: refute(has_element?(erin, ~s(.hand a.card[phx-value-id="#{id}"])))
    refute has_element?(erin, ".pile")
    refute render(erin) =~ "Color:"
    assert has_element?(erin, ".your-turn", "Your turn")
    assert has_element?(erin, ".stage-hint", "Match the top card on the table.")
    assert has_element?(erin, "main.glow-turn")
  end

  test "tapping a card plays it", %{erin: erin} do
    start!()
    sync(erin)
    tap_card(erin, 2)

    assert Rules.top_card(Room.get_state().game).id == 2
    assert has_element?(erin, ".turn", "Bob's turn")
    refute has_element?(erin, "main.glow-turn")
  end

  test "a card out of turn gets Not your turn; OK hides it", %{erin: erin} do
    start!()
    sync(erin)
    tap_card(erin, 2)
    tap_card(erin, 3)

    assert has_element?(erin, ".toast", "Not your turn")
    erin |> element(".toast") |> render_click()
    refute has_element?(erin, ".toast")
  end

  test "a card that doesn't match names the top card", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> put_in(game.hands["erin"], [c(50, :blue, 9), c(2, :red, 1)]) end)
    tap_card(erin, 50)

    assert has_element?(erin, ".toast", "Doesn't match: red 5")
  end

  test "a Wild asks for a color first; only the four colors count", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> put_in(game.hands["erin"], [c(60, nil, :wild), c(2, :red, 1)]) end)
    tap_card(erin, 60)
    assert has_element?(erin, ".sheet h2", "Pick a color")

    render_click(with_target(erin, "#uno-phone"), "pick_color", %{"color" => "purple"})
    assert has_element?(erin, ".sheet h2", "Pick a color")

    erin |> element(".swatch.green") |> render_click()
    assert Room.get_state().game.color == :green
    refute has_element?(erin, ".sheet")
  end

  test "a 7 under 7-0 asks who to swap with", %{erin: erin} do
    :ok = Room.update_settings(%{seven_zero: true})
    start!()
    sync(erin)
    tap_card(erin, 8)

    assert has_element?(erin, ".sheet h2", "Swap hands with…")
    erin |> element(".pick-list a", "Bob") |> render_click()
    assert ids(Room.get_state().game.hands["erin"]) == Enum.to_list(9..15)
  end

  test "a +4 aimed at you says who played it and offers Draw 4 and Challenge", %{erin: erin} do
    start!()
    tweak_game(erin, &facing_plus4/1)

    assert has_element?(erin, ".threat", "+4")
    assert has_element?(erin, ".threat-sub", "Bob played it.")
    assert has_element?(erin, ".actions button", "Draw 4")

    erin |> element(".actions button", "Challenge") |> render_click()
    assert has_element?(erin, ".toast", "Bob had no red card, so the +4 was fair. You drew 6.")
  end

  test "with stacking on, the phone says how to get out of a penalty", %{erin: erin} do
    :ok = Room.update_settings(%{stack_plus4: true})
    start!()
    tweak_game(erin, &facing_plus4/1)

    assert has_element?(erin, ".hint", "Or tap a +4 in your hand to stack it.")
    tap_card(erin, 2)
    assert has_element?(erin, ".toast", "Draw 4, challenge, or stack a +4 first")
  end

  test "a playable drawn card can be played or kept", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> %{game | draw_pile: [c(500, :red, 8) | game.draw_pile]} end)
    erin |> element(".actions button", "Draw") |> render_click()

    assert has_element?(erin, ".sheet h2", "You drew a red 8")
    erin |> element(".sheet button", "Keep it") |> render_click()
    assert has_element?(erin, ".turn", "Bob's turn")
  end

  test "a starting Wild asks the first player for the color", %{erin: erin} do
    use_deck(deck_starting_with(2, :wild))
    start!()
    sync(erin)

    assert has_element?(erin, ".sheet h2", "Pick the starting color")
    erin |> element(".swatch.blue") |> render_click()
    assert Room.get_state().game.color == :blue
  end

  test "the winner's phone says You won!", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> put_in(game.hands["erin"], [c(2, :red, 1)]) end)
    tap_card(erin, 2)

    assert has_element?(erin, "h1.huge", "You won!")
    assert has_element?(erin, ".wait", "Waiting for the table")
  end

  test "someone joining mid-round waits in line" do
    start!()
    {:ok, carol, _html} = live(phone(build_conn(), "carol"), ~p"/")
    carol |> form("#join", %{name: "Carol"}) |> render_submit()

    assert has_element?(carol, "h1", "You're #1 in line.")
    assert has_element?(carol, ".lead", "A game is in progress. You'll play in the next one.")
  end
end
