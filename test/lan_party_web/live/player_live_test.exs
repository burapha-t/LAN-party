defmodule LanPartyWeb.PlayerLiveTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room

  setup do
    restart_room()
  end

  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  test "a new phone sees the join screen", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    assert has_element?(view, "form#join input[name=name]")
    assert has_element?(view, ".wordmark", "LAN Party")
  end

  test "joining shows who is here while the table picks a game", %{conn: conn} do
    :ok = Room.join("alice", "Alice", page())
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    view |> form("#join", %{name: "Erin"}) |> render_submit()

    assert has_element?(view, ".wait", "Waiting for the table to pick a game")
    assert has_element?(view, ".people li.you", "Erin (you)")
    assert has_element?(view, ".people li", "Alice")
    assert has_element?(view, ".bar strong", "Erin")
  end

  test "a taken name is refused", %{conn: conn} do
    :ok = Room.join("alice", "Alice", page())
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    view |> form("#join", %{name: " alice"}) |> render_submit()

    assert has_element?(view, ".field-error", "That name is taken. Try another.")
  end

  test "a joined phone that reloads skips the join screen", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")
    view |> form("#join", %{name: "Erin"}) |> render_submit()

    {:ok, again, _html} = live(phone(build_conn(), "erin"), ~p"/")
    refute has_element?(again, "form#join")
    assert has_element?(again, ".wait", "Waiting for the table to pick a game")
  end

  test "a kicked phone is told why, with its name filled in", %{conn: conn} do
    :sys.replace_state(Room, fn state -> %{state | kicked: Map.put(state.kicked, "erin", "Erin")} end)
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    assert has_element?(view, ".notice", "You were away too long and left the game.")
    assert has_element?(view, ~s(input#name[value="Erin"]))
  end

  test "a phone the table removed is told so, with its name filled in", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")
    view |> form("#join", %{name: "Erin"}) |> render_submit()
    :ok = Room.pick_game(:uno)
    :ok = Room.remove("erin")
    sync(view)

    assert has_element?(view, ".notice", "The table removed you from the game.")
    assert has_element?(view, ~s(input#name[value="Erin"]))
  end

  test "when the Room restarts, the phone reloads", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")
    Process.exit(Process.whereis(Room), :kill)

    assert_redirect(view, ~p"/")
  end
end
