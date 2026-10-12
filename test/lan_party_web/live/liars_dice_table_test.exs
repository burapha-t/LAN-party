defmodule LanPartyWeb.LiarsDiceTableTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers, only: [sync: 1, restart_room: 0]

  alias LanParty.Room

  # Every roll: five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Erin is in the Liar's Dice lobby, and the table is open.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, fn state -> %{state | game_opts: [roller: &fixed/1]} end)
    :ok = Room.join("erin", "Erin", page())
    :ok = Room.pick_game(:liars_dice)
    {:ok, table, _html} = live(conn, ~p"/table")
    %{table: table}
  end

  defp join(table, token, name) do
    :ok = Room.join(token, name, page())
    sync(table)
  end

  defp start(table, others \\ [{"bob", "Bob"}]) do
    for {token, name} <- others, do: join(table, token, name)
    table |> element("button", "Start game") |> render_click()
  end

  # Change the Room behind the table's back, then let the table re-render.
  defp tweak_room(table, fun) do
    :sys.replace_state(Room, fun)
    send(table.pid, {:party_updated, Room.get_state()})
    sync(table)
  end

  defp set_dice(table, dice),
    do:
      tweak_room(table, fn state -> put_in(state.game.dice, Map.merge(state.game.dice, dice)) end)

  defp tap_seat(table, token),
    do: table |> element(~s(a.seat[phx-value-token="#{token}"])) |> render_click()

  defp component(table), do: with_target(table, "#liars-dice-table")

  describe "the lobby" do
    test "shows the players; Start needs 2", %{table: table} do
      assert has_element?(table, ".wordmark", "Liar's Dice")
      assert has_element?(table, ".lobby.solo", "Erin")
      assert has_element?(table, "button", "Change game")
      assert has_element?(table, "button[disabled]", "Start game")
      assert has_element?(table, ".start-row p", "Start needs at least 2 players.")

      join(table, "bob", "Bob")
      refute has_element?(table, "button[disabled]", "Start game")
      assert has_element?(table, ".start-row p", "Everyone starts with 5 dice.")
    end

    test "Change game goes back to Select the game", %{table: table} do
      table |> element("button", "Change game") |> render_click()
      assert has_element?(table, "h1", "Select the game")
    end
  end

  describe "the shelf" do
    setup %{table: table} do
      table |> element("button", "Change game") |> render_click()
      :ok
    end

    test "has a Liar's Dice box instead of its spine; tapping it selects Liar's Dice", %{
      table: table
    } do
      assert has_element?(table, ".box-dice .box-tag", "2 to 8 players")
      assert has_element?(table, ".box-dice .box-art .pips.n6")
      refute has_element?(table, ".spine b", "Liar's Dice")

      refute has_element?(table, ".shelved")

      table |> element(".box-dice") |> render_click()
      assert has_element?(table, ".box-dice.selected")
      refute has_element?(table, ".box-uno.selected")
      assert Room.get_state().game_id == nil
    end

    test "the box not tapped goes back on the shelf as a spine; tapping it swaps", %{table: table} do
      table |> element(".box-dice") |> render_click()
      assert has_element?(table, ".box-uno.shelved .box-spine b", "UNO")
      refute has_element?(table, ".box-dice.shelved")

      table |> element(".box-uno") |> render_click()
      assert has_element?(table, ".box-uno.selected")
      assert has_element?(table, ".box-dice.shelved .box-spine b", "Liar's Dice")
    end

    test "the side panel shows only the tapped game, and its Play button picks it", %{
      table: table
    } do
      refute has_element?(table, ".selected")
      assert has_element?(table, ".shelf-aside p", "Tap a game to choose it.")
      refute has_element?(table, ".shelf-aside button")

      table |> element(".box-uno") |> render_click()
      table |> element(".box-dice") |> render_click()
      assert has_element?(table, ".shelf-aside p", "Bluff about hidden dice.")
      refute has_element?(table, ".shelf-aside p", "The classic card game.")
      refute has_element?(table, ".shelf-aside button", "Play UNO")

      table |> element(".shelf-aside button", "Play Liar's Dice") |> render_click()
      assert Room.get_state().game_id == :liars_dice
      assert has_element?(table, ".wordmark", "Liar's Dice")
    end

    test "Change game comes back with nothing selected", %{table: table} do
      table |> element(".box-dice") |> render_click()
      table |> element(".shelf-aside button", "Play Liar's Dice") |> render_click()
      table |> element("button", "Change game") |> render_click()

      refute has_element?(table, ".selected")
    end
  end

  describe "a game" do
    test "every seat has 5 dice; the total, the face picker and Roll; never a die's value", %{
      table: table
    } do
      start(table)

      assert has_element?(table, ".seat .name", "Erin")
      assert has_element?(table, ".seat .name", "Bob")
      assert has_element?(table, ".seat .count", "5")
      assert has_element?(table, ".dice-total b", "10")
      assert has_element?(table, ".dice-total", "dice in play")

      assert has_element?(
               table,
               ".face-pick p",
               ~s(Someone called "Liar!"? Pick the face that was bid.)
             )

      for face <- 2..6 do
        assert has_element?(
                 table,
                 ~s(.face-btn[aria-label="Count #{face}s"][aria-pressed="false"])
               )
      end

      assert has_element?(table, "button.roll", "Roll")
      assert has_element?(table, "button", "Reset")
      assert has_element?(table, ".tv-foot", "Tap a player to take a die.")
      refute has_element?(table, ".die")
    end

    test "picking a face raises it; another face moves it; Roll clears it", %{table: table} do
      start(table)

      table |> element(~s(.face-btn[aria-label="Count 4s"])) |> render_click()
      assert Room.get_state().game.face == 4
      assert has_element?(table, ~s(.face-btn[aria-label="Count 4s"][aria-pressed="true"]))

      assert has_element?(
               table,
               ".face-pick p",
               "Counting 4s. 1s are wild. Count the phones out loud."
             )

      table |> element(~s(.face-btn[aria-label="Count 6s"])) |> render_click()
      assert has_element?(table, ~s(.face-btn[aria-label="Count 6s"][aria-pressed="true"]))
      refute has_element?(table, ~s(.face-btn[aria-label="Count 4s"][aria-pressed="true"]))

      table |> element("button.roll") |> render_click()
      assert Room.get_state().game.roll == 2
      refute has_element?(table, ~s(.face-btn[aria-pressed="true"]))
    end

    test "a junk face is ignored", %{table: table} do
      start(table)
      table |> component() |> render_click("count", %{"face" => "7"})
      table |> component() |> render_click("count", %{"face" => "x"})
      assert Room.get_state().game.face == nil
    end

    test "away players are tagged and their dice still count", %{table: table} do
      start(table)
      tweak_room(table, fn state -> put_in(state.people["bob"].pids, MapSet.new()) end)

      assert has_element?(table, ".seat.away .pill", "Away")
      assert has_element?(table, ".dice-total b", "10")
    end

    test "late joiners show in the footer", %{table: table} do
      start(table)
      join(table, "gus", "Gus")
      assert has_element?(table, ".tv-foot .next", "Gus")
    end
  end

  describe "taking a die" do
    test "tapping a player opens the panel; Cancel changes nothing", %{table: table} do
      start(table)
      tap_seat(table, "erin")

      assert has_element?(table, ".modal h2", "Take a die from Erin?")
      assert has_element?(table, ".modal p", "Erin goes from 5 dice to 4.")

      table |> element(".modal button", "Cancel") |> render_click()
      refute has_element?(table, ".modal")
      assert length(Room.get_state().game.dice["erin"]) == 5
    end

    test "Remove takes one die; a second tap takes nothing more", %{table: table} do
      start(table)
      tap_seat(table, "erin")
      table |> element(".modal button", "Remove") |> render_click()

      assert length(Room.get_state().game.dice["erin"]) == 4
      refute has_element?(table, ".modal")
      assert has_element?(table, ".dice-total b", "9")

      # A second "take" arriving after the panel closed is ignored.
      table |> component() |> render_click("take", %{})
      assert length(Room.get_state().game.dice["erin"]) == 4
    end

    test "a player's last die: the panel says they're out, and the seat lies flat", %{
      table: table
    } do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")

      assert has_element?(table, ".modal h2", "Take Erin's last die?")
      assert has_element?(table, ".modal p", "Erin is out of the game.")

      table |> element(".modal button", "Remove") |> render_click()
      assert has_element?(table, ".seat.out .name", "Erin")
      assert has_element?(table, ".seat.out .pill", "Out")
      refute has_element?(table, ~s(a.seat[phx-value-token="erin"]))
    end

    test "an Out seat can't be tapped", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"carol" => []})

      refute has_element?(table, ~s(a.seat[phx-value-token="carol"]))
      table |> component() |> render_click("open_take", %{"token" => "carol"})
      table |> component() |> render_click("open_take", %{"token" => "nobody"})
      refute has_element?(table, ".modal")
    end

    test "when the last die ends the game, the panel says who wins; then the winner shows", %{
      table: table
    } do
      start(table)
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")
      assert has_element?(table, ".modal p", "Erin is out, and Bob wins.")

      table |> element(".modal button", "Remove") |> render_click()
      assert has_element?(table, ".winner h1", "Bob won")
      assert has_element?(table, ".winner .lead", "Last one with dice")
      assert has_element?(table, ".winner button", "Play again")
    end

    test "the panel closes when its player loses their last die at another table", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")

      :ok = Room.table_act({:take_die, "erin"})
      sync(table)
      refute has_element?(table, ".modal")
    end

    test "a take that fails says so", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")

      # Another table took it, and this table hasn't heard yet.
      :sys.replace_state(Room, fn state -> put_in(state.game.dice["erin"], []) end)
      table |> element(".modal button", "Remove") |> render_click()
      assert has_element?(table, ".tv-foot [role=alert]", "That didn't work. Try again.")
    end
  end

  describe "the end" do
    test "Reset asks first, then everyone goes back to the lobby", %{table: table} do
      start(table)
      table |> element("button", "Reset") |> render_click()

      assert has_element?(table, ".modal h2", "End this game?")
      assert has_element?(table, ".modal p", "Nobody wins, and everyone goes back to the lobby.")

      table |> element(".modal button", "End game") |> render_click()
      assert Room.get_state().phase == :lobby
      assert has_element?(table, "button", "Start game")
    end

    test "late joiners join at Play again", %{table: table} do
      start(table)
      join(table, "gus", "Gus")
      set_dice(table, %{"erin" => [3]})
      :ok = Room.table_act({:take_die, "erin"})
      sync(table)

      assert has_element?(table, ".winner .lobby-note", "Gus joins at Play again.")
      table |> element("button", "Play again") |> render_click()
      assert Room.seated(Room.get_state()) == ["erin", "bob", "gus"]
    end

    test "the result survives the winner leaving", %{table: table} do
      start(table)
      set_dice(table, %{"erin" => [3]})
      :ok = Room.table_act({:take_die, "erin"})

      tweak_room(table, fn state ->
        %{state | people: Map.delete(state.people, "bob"), order: List.delete(state.order, "bob")}
      end)

      assert has_element?(table, ".winner h1", "Someone won")
    end
  end
end
