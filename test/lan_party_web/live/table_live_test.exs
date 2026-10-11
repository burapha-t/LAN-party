defmodule LanPartyWeb.TableLiveTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room

  setup do
    restart_room()
  end

  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  test "the table starts on Select the game, listing every game and who has joined", %{conn: conn} do
    :ok = Room.join("erin", "Erin", page())
    {:ok, view, _html} = live(conn, ~p"/table")

    assert has_element?(view, "h1", "Select the game")
    assert has_element?(view, ".joined", "Joined so far: Erin")

    for name <- ["Quiplash", "Paranoia", "Who wrote it?", "Love Letter", "Never Have I Ever", "Killer"] do
      assert has_element?(view, ".spine b", name)
    end

    assert has_element?(view, ".spine small", "Not built yet")
  end

  test "picking UNO switches every phone to UNO", %{conn: conn} do
    {:ok, phone, _html} = live(Plug.Test.init_test_session(conn, %{"player_token" => "erin"}), ~p"/")
    phone |> form("#join", %{name: "Erin"}) |> render_submit()

    {:ok, table, _html} = live(build_conn(), ~p"/table")
    table |> element(".shelf-aside button", "Play UNO") |> render_click()

    assert Room.get_state().game_id == :uno
    sync(phone)
    assert has_element?(phone, ".brand", "UNO")
  end

  test "a game that isn't built can't be picked", %{conn: conn} do
    {:ok, table, _html} = live(conn, ~p"/table")
    render_click(table, "pick_game", %{"id" => "quiplash"})

    assert Room.get_state().game_id == nil
  end
end
