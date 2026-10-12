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
    table |> element(".box-uno") |> render_click()
    table |> element(".shelf-aside button", "Play UNO") |> render_click()

    assert Room.get_state().game_id == :uno
    sync(phone)
    assert has_element?(phone, ".wordmark", "UNO")
  end

  test "a game that isn't built can't be picked", %{conn: conn} do
    {:ok, table, _html} = live(conn, ~p"/table")
    render_click(table, "pick_game", %{"id" => "quiplash"})

    assert Room.get_state().game_id == nil
  end

  describe "in a game's lobby" do
    setup %{conn: conn} do
      :ok = Room.join("erin", "Erin", page())
      :ok = Room.pick_game(:liars_dice)
      {:ok, table, _html} = live(conn, ~p"/table")
      %{table: table}
    end

    test "tapping a player opens the Remove panel, and the X closes it", %{table: table} do
      table |> element(".roster button", "Erin") |> render_click()
      assert has_element?(table, ".modal h2", "Remove Erin?")

      table |> element(".modal-x") |> render_click()
      refute has_element?(table, ".modal")
      assert Room.name(Room.get_state(), "erin") == "Erin"
    end

    test "Remove takes the player out", %{table: table} do
      table |> element(".roster button", "Erin") |> render_click()
      table |> element(".modal button", "Remove") |> render_click()
      sync(table)

      refute Map.has_key?(Room.get_state().people, "erin")
      refute has_element?(table, ".modal")
      refute has_element?(table, ".roster li", "Erin")
    end
  end
end
