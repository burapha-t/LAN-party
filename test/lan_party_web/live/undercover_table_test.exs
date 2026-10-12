defmodule LanPartyWeb.UndercoverTableTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers, only: [sync: 1, restart_room: 0]

  alias LanParty.Room
  alias LanParty.Undercover.Rules

  # Made-up words nothing else on the page can contain, and a fixed shuffle: no test depends on
  # pairs.txt. With this shuffle the first seated player is the undercover.
  @pairs [{"Zorblax", "Quuxington"}, {"Wumpus", "Fnordle"}, {"Plinth", "Gribbet"}]
  @words Enum.flat_map(@pairs, &Tuple.to_list/1)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)
  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})

  # Erin is in the Undercover lobby, and the table is open.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, fn state -> %{state | game_opts: [pairs: @pairs, shuffle: & &1]} end)
    :ok = Room.join("erin", "Erin", page())
    :ok = Room.pick_game(:undercover)
    {:ok, table, _html} = live(conn, ~p"/table")
    %{table: table}
  end

  defp join(table, token, name) do
    :ok = Room.join(token, name, page())
    sync(table)
  end

  defp start(table, others \\ [{"bob", "Bob"}, {"carol", "Carol"}]) do
    for {token, name} <- others, do: join(table, token, name)
    table |> element("button", "Start game") |> render_click()
  end

  # Change the Room behind the table's back, then let the table re-render.
  defp tweak_room(table, fun) do
    :sys.replace_state(Room, fun)
    send(table.pid, {:party_updated, Room.get_state()})
    sync(table)
  end

  defp component(table), do: with_target(table, "#undercover-table")

  describe "the lobby" do
    test "shows the players; Start needs 3", %{table: table} do
      assert has_element?(table, ".wordmark", "Undercover")
      assert has_element?(table, ".lobby.solo", "Erin")
      assert has_element?(table, "button", "Change game")
      assert has_element?(table, "button[disabled]", "Start game")
      assert has_element?(table, ".start-row p", "Start needs at least 3 players.")

      join(table, "bob", "Bob")
      assert has_element?(table, "button[disabled]", "Start game")
      assert has_element?(table, ".start-row p", "Start needs at least 3 players.")

      join(table, "carol", "Carol")
      refute has_element?(table, "button[disabled]", "Start game")
      refute has_element?(table, ".start-row p")
    end

    test "a Start that arrives with too few players says so", %{table: table} do
      join(table, "bob", "Bob")
      table |> component() |> render_click("start", %{})

      assert has_element?(table, ".start-row p[role=alert]", "Start needs at least 3 players.")
      assert Room.get_state().phase == :lobby
    end

    test "tapping a player opens the Remove panel", %{table: table} do
      table |> element(".roster button", "Erin") |> render_click()
      assert has_element?(table, ".modal h2", "Remove Erin?")
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

    test "has an Undercover box with two slips, and no spine of its own", %{table: table} do
      assert has_element?(table, ~s(.box-undercover[aria-label="Undercover, 3 to 8 players"]))
      assert has_element?(table, ".box-undercover .box-logo", "Undercover")
      assert has_element?(table, ".box-undercover .box-tag", "3 to 8 players")
      assert has_element?(table, ".box-undercover .box-art .slip .slip-word", "Coffee")
      assert has_element?(table, ".box-undercover .box-art .slip .slip-word", "Tea")
      assert has_element?(table, ".box-undercover.shelved .box-spine b", "Undercover")
      refute has_element?(table, ".spine b", "Undercover")
    end

    test "all three games are on the shelf; the unbuilt ones are still spines", %{table: table} do
      assert has_element?(table, ".box-uno.shelved")
      assert has_element?(table, ".box-dice.shelved")
      assert has_element?(table, ".box-undercover.shelved")
      assert has_element?(table, ".spine b", "Quiplash")
    end

    test "tapping the box only selects it; the others stay spines", %{table: table} do
      table |> element(".box-undercover") |> render_click()

      assert has_element?(table, ".box-undercover.selected")
      assert has_element?(table, ".box-uno.shelved")
      assert has_element?(table, ".box-dice.shelved")
      assert Room.get_state().game_id == nil

      table |> element(".box-dice") |> render_click()
      assert has_element?(table, ".box-dice.selected")
      assert has_element?(table, ".box-undercover.shelved")
    end

    test "the side panel describes Undercover, and its Play button picks it", %{table: table} do
      table |> element(".box-undercover") |> render_click()

      assert has_element?(table, ".shelf-aside h2", "Undercover")
      assert has_element?(table, ".shelf-aside p", "Find who has a different word.")
      refute has_element?(table, ".shelf-aside button", "Play UNO")

      table |> element(".shelf-aside button", "Play Undercover") |> render_click()
      assert Room.get_state().game_id == :undercover
      assert has_element?(table, ".wordmark", "Undercover")
    end
  end

  describe "a game" do
    test "every seat has a name and nothing else; the undercover count, Reroll and Reset", %{
      table: table
    } do
      start(table)

      for name <- ["Erin", "Bob", "Carol"], do: assert(has_element?(table, ".seat .name", name))
      refute has_element?(table, ".seat .count")
      assert has_element?(table, ".felt.felt-undercover .undercover-total b", "1")
      assert has_element?(table, ".undercover-total span", "undercover")
      refute has_element?(table, ".undercover-total span", "undercovers")

      assert has_element?(
               table,
               ".felt-note",
               "Describe your word without saying it. Then vote someone out."
             )

      assert has_element?(table, "button.btn-big.roll", "Reroll")
      assert has_element?(table, "button", "Reset")
      assert has_element?(table, ".tv-foot", "Voted out? Show your phone.")
    end

    test "seats can't be tapped", %{table: table} do
      start(table)

      refute has_element?(table, "a.seat")
      refute has_element?(table, ".seat[phx-click]")
      assert has_element?(table, ".seat.plain", "Erin")
    end

    test "with 6 to 8 players the count is 2 and the label is plural", %{table: table} do
      start(table, [
        {"bob", "Bob"},
        {"carol", "Carol"},
        {"dan", "Dan"},
        {"fay", "Fay"},
        {"gus", "Gus"}
      ])

      assert has_element?(table, ".undercover-total b", "2")
      assert has_element?(table, ".undercover-total span", "undercovers")
    end

    test "the table never shows a word, before or after a Reroll", %{table: table} do
      start(table)
      before_reroll = render(table)
      table |> element("button.roll") |> render_click()
      after_reroll = render(table)

      words = Room.get_state().game.words |> Map.values()
      assert words != []

      for html <- [before_reroll, after_reroll], word <- @words do
        refute html =~ word
      end
    end

    test "Reroll deals a new pair to every phone and keeps the count", %{table: table, conn: conn} do
      {:ok, erin, _html} = live(phone(conn, "erin"), ~p"/")
      {:ok, bob, _html} = live(phone(conn, "bob"), ~p"/")
      start(table)
      sync([erin, bob])
      assert has_element?(erin, ".slip-word", "Quuxington")
      assert has_element?(bob, ".slip-word", "Zorblax")

      table |> element("button.roll", "Reroll") |> render_click()
      sync([erin, bob])

      assert Room.get_state().game.deal == 2
      assert has_element?(erin, "#slip-2 .slip-word", "Fnordle")
      assert has_element?(bob, "#slip-2 .slip-word", "Wumpus")
      assert has_element?(table, ".undercover-total b", "1")
    end

    test "away players are tagged", %{table: table} do
      start(table)
      tweak_room(table, fn state -> put_in(state.people["bob"].pids, MapSet.new()) end)

      assert has_element?(table, ".seat.away .pill", "Away")
      assert has_element?(table, ".seat .name", "Bob")
    end

    test "after a kick the seat goes and the dealt count stays", %{table: table} do
      start(table, [
        {"bob", "Bob"},
        {"carol", "Carol"},
        {"dan", "Dan"},
        {"fay", "Fay"},
        {"gus", "Gus"}
      ])

      tweak_room(table, fn state ->
        state = put_in(state.game, Rules.remove_player(state.game, "gus"))
        %{state | people: Map.delete(state.people, "gus"), order: List.delete(state.order, "gus")}
      end)

      refute has_element?(table, ".seat .name", "Gus")
      assert has_element?(table, ".undercover-total b", "2")
    end

    test "late joiners show in the footer", %{table: table} do
      start(table)
      join(table, "gus", "Gus")
      assert has_element?(table, ".tv-foot .next", "Next game:")
      assert has_element?(table, ".tv-foot .next", "Gus")
    end

    test "a Reroll that fails says so", %{table: table} do
      start(table)
      :sys.replace_state(Room, fn state -> %{state | phase: :lobby} end)
      table |> component() |> render_click("reroll", %{})

      assert has_element?(table, "[role=alert]", "That didn't work. Try again.")
    end
  end

  describe "the end" do
    test "Reset asks first, then everyone goes back to the lobby", %{table: table} do
      start(table)
      table |> element("button", "Reset") |> render_click()

      assert has_element?(table, ".modal h2", "End this game?")
      assert has_element?(table, ".modal p", "Nobody wins, and everyone goes back to the lobby.")

      table |> element(".modal button", "Cancel") |> render_click()
      refute has_element?(table, ".modal")
      assert Room.get_state().phase == :playing

      table |> element("button", "Reset") |> render_click()
      table |> element(".modal button", "End game") |> render_click()
      assert Room.get_state().phase == :lobby
      assert has_element?(table, "button", "Start game")
    end

    test "the last one left is the winner; late joiners join at Play again", %{table: table} do
      start(table)
      join(table, "gus", "Gus")
      tweak_room(table, fn state -> %{state | phase: :finished, winner: "bob"} end)

      assert has_element?(table, ".winner h1", "Bob won")
      assert has_element?(table, ".winner .lead", "Last one left")
      assert has_element?(table, ".winner .lobby-note", "Gus joins at Play again.")
      refute has_element?(table, ".slip")

      table |> element("button", "Play again") |> render_click()
      assert Room.get_state().phase == :lobby
      assert Room.seated(Room.get_state()) == ["erin", "bob", "carol", "gus"]
    end

    test "the result survives the winner leaving", %{table: table} do
      start(table)

      tweak_room(table, fn state ->
        %{
          state
          | phase: :finished,
            winner: "bob",
            people: Map.delete(state.people, "bob"),
            order: List.delete(state.order, "bob")
        }
      end)

      assert has_element?(table, ".winner h1", "Someone won")
    end
  end
end
