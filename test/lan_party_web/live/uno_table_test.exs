defmodule LanPartyWeb.UnoTableTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room

  # Erin and Bob; with the fixed deck Erin goes first and red 5 starts the pile.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, &%{&1 | game_opts: [deck: deck_starting_with(2, 5), first_player: "erin"]})
    :ok = Room.join("erin", "Erin", page())
    :ok = Room.pick_game(:uno)
    {:ok, table, _html} = live(conn, ~p"/table")
    %{table: table}
  end

  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  defp start_round(table) do
    :ok = Room.join("bob", "Bob", page())
    sync(table)
    table |> element("button", "Start game") |> render_click()
  end

  test "the lobby waits for a second player", %{table: table} do
    assert has_element?(table, ".wordmark", "UNO")
    assert has_element?(table, ".roster li", "Erin")
    assert has_element?(table, ".roster li .avatar.p1", "E")
    assert has_element?(table, ".panel .wait", "Waiting for players to join")
    assert has_element?(table, "button[disabled]", "Start game")
    assert has_element?(table, ".start-row p", "Start needs at least 2 players.")
  end

  test "with two players the table can start", %{table: table} do
    :ok = Room.join("bob", "Bob", page())
    sync(table)

    assert has_element?(table, ".seats-left", "2 of 8 seats taken")
    refute has_element?(table, "button[disabled]", "Start game")
  end

  test "house rules switch on and off", %{table: table} do
    table |> element("#rule-jump_in") |> render_click()

    assert Room.get_state().settings.jump_in
    assert has_element?(table, "#rule-jump_in[checked]")
  end

  test "Change game goes back to Select the game", %{table: table} do
    table |> element("button", "Change game") |> render_click()

    assert Room.get_state().phase == :picking
    assert has_element?(table, "h1", "Select the game")
  end

  test "during a round the table shows seats, the pile and whose turn it is", %{table: table} do
    start_round(table)

    assert has_element?(table, ".seat.current .name", "Erin")
    assert has_element?(table, ".seat .count", "7")
    assert has_element?(table, ".table-info .turn", "Erin's turn")
    assert has_element?(table, ".facts", "Color: red")
    assert has_element?(table, ".top-card .card.red")
    assert has_element?(table, ".felt.felt-red")
    refute has_element?(table, "button", "Change game")
  end

  test "draw for player: tap a seat, pick the amount, Draw", %{table: table} do
    start_round(table)
    table |> element(".seat", "Bob") |> render_click()

    assert has_element?(table, ".modal h2", "Make Bob draw")
    assert has_element?(table, ".stepper output", "2")
    table |> element(".stepper button[aria-label='One more']") |> render_click()
    assert has_element?(table, ".stepper output", "3")

    table |> element(".modal button", "Draw") |> render_click()
    assert length(Room.get_state().game.hands["bob"]) == 10
    refute has_element?(table, ".modal")
  end

  test "Reset asks before ending the round", %{table: table} do
    start_round(table)

    table |> element("button", "Reset") |> render_click()
    assert has_element?(table, ".modal h2", "End this round?")
    table |> element(".modal button", "Cancel") |> render_click()
    assert Room.get_state().phase == :playing

    table |> element("button", "Reset") |> render_click()
    table |> element(".modal button", "End round") |> render_click()
    assert Room.get_state().phase == :lobby
  end

  test "the winner screen, then Play again", %{table: table} do
    start_round(table)
    :sys.replace_state(Room, fn state -> put_in(state.game.hands["erin"], [c(2, :red, 1)]) end)
    :ok = Room.act("erin", {:play, 2, %{}})
    sync(table)

    assert has_element?(table, ".winner h1", "Erin won")
    assert has_element?(table, ".leftovers", "Bob")

    table |> element("button", "Play again") |> render_click()
    assert Room.get_state().phase == :lobby
  end
end
