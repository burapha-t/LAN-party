defmodule LanPartyWeb.UndercoverPhoneTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers, only: [sync: 1, restart_room: 0]

  alias LanParty.Room
  alias LanParty.Undercover.Rules

  # Made-up pairs and a fixed shuffle, so no test depends on pairs.txt. With this shuffle the first
  # seated player (Erin) is the undercover and holds the first pair's second word.
  @pairs [{"Alpha", "Beta"}, {"Cedar", "Dune"}, {"Ember", "Fjord"}]
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)
  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})

  # Erin (this phone), Bob and Carol, in the Undercover lobby.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, fn state -> %{state | game_opts: [pairs: @pairs, shuffle: & &1]} end)
    {:ok, erin, _html} = live(phone(conn, "erin"), ~p"/")
    erin |> form("#join", %{name: "Erin"}) |> render_submit()
    :ok = Room.join("bob", "Bob", page())
    :ok = Room.join("carol", "Carol", page())
    :ok = Room.pick_game(:undercover)
    sync(erin)
    %{erin: erin}
  end

  # Change the Room behind the phones' backs, then let each phone re-render.
  defp tweak_room(views, fun) do
    :sys.replace_state(Room, fun)

    for view <- List.wrap(views) do
      send(view.pid, {:party_updated, Room.get_state()})
      sync(view)
    end
  end

  defp more_players(view, names) do
    for name <- names, do: :ok = Room.join(String.downcase(name), name, page())
    sync(view)
  end

  test "the phone follows the table to Undercover and waits in the lobby", %{erin: erin} do
    assert has_element?(erin, ".wordmark", "Undercover")
    assert render(erin) =~ "Waiting for the table to start"
  end

  describe "a deal" do
    test "Start game: your word on a paper slip, and how many players have a different one; no buttons",
         %{erin: erin} do
      :ok = Room.start_game()
      sync(erin)

      assert has_element?(
               erin,
               ~s(.stage[aria-label="Your word"] #slip-1.slip .slip-word),
               "Beta"
             )

      assert has_element?(erin, ".stage-hint", "1 player has a different word. It could be you.")
      refute has_element?(erin, "button")
    end

    test "the phone never says what you are", %{erin: erin} do
      :ok = Room.start_game()
      sync(erin)

      stage = erin |> element(".stage") |> render()
      refute stage =~ ~r/undercover|civilian|role/i
    end

    test "with 6 to 8 players the hint says 2", %{erin: erin} do
      more_players(erin, ["Dan", "Fay", "Gus"])
      :ok = Room.start_game()
      sync(erin)

      assert has_element?(
               erin,
               ".stage-hint",
               "2 players have a different word. It could be you."
             )
    end

    test "a kick during a deal doesn't change the count the phone shows", %{erin: erin} do
      more_players(erin, ["Dan", "Fay", "Gus"])
      :ok = Room.start_game()
      tweak_room(erin, fn state -> put_in(state.game, Rules.remove_player(state.game, "gus")) end)

      assert has_element?(
               erin,
               ".stage-hint",
               "2 players have a different word. It could be you."
             )
    end

    test "a phone shows only its own word", %{erin: erin} do
      :ok = Room.start_game()
      sync(erin)

      assert has_element?(erin, ".slip-word", "Beta")
      refute has_element?(erin, ".slip-word", "Alpha")
    end

    test "Reroll gives every phone a new word", %{erin: erin, conn: conn} do
      {:ok, bob, _html} = live(phone(conn, "bob"), ~p"/")
      :ok = Room.start_game()
      sync([erin, bob])
      assert has_element?(bob, ".slip-word", "Alpha")

      :ok = Room.table_act(:reroll)
      sync([erin, bob])

      assert has_element?(erin, "#slip-2 .slip-word", "Dune")
      assert has_element?(bob, "#slip-2 .slip-word", "Cedar")
      refute has_element?(erin, "#slip-1")
    end
  end

  describe "the deal-in motion" do
    test "a deal that happens while the page is open slides in", %{erin: erin} do
      :ok = Room.start_game()
      sync(erin)
      assert has_element?(erin, "#slip-1.slip.dealt")

      :ok = Room.table_act(:reroll)
      sync(erin)
      assert has_element?(erin, "#slip-2.slip.dealt")
    end

    test "a phone opened mid-game shows its word already landed; the next deal slides in", %{
      conn: conn
    } do
      :ok = Room.start_game()
      {:ok, again, _html} = live(phone(conn, "erin"), ~p"/")

      assert has_element?(again, "#slip-1.slip")
      refute has_element?(again, ".slip.dealt")

      :ok = Room.table_act(:reroll)
      sync(again)
      assert has_element?(again, "#slip-2.slip.dealt")
      refute has_element?(again, "#slip-1")
    end

    test "a phone opened mid-game still animates the first deal of the next game", %{conn: conn} do
      :ok = Room.start_game()
      :ok = Room.table_act(:reroll)
      {:ok, again, _html} = live(phone(conn, "erin"), ~p"/")
      refute has_element?(again, ".slip.dealt")

      :ok = Room.back_to_lobby()
      sync(again)
      :ok = Room.start_game()
      sync(again)
      assert has_element?(again, "#slip-1.slip.dealt")
    end
  end

  describe "the result" do
    test "the last one left wins; the others see who", %{erin: erin, conn: conn} do
      {:ok, bob, _html} = live(phone(conn, "bob"), ~p"/")
      :ok = Room.start_game()
      tweak_room([erin, bob], fn state -> %{state | phase: :finished, winner: "erin"} end)

      assert has_element?(erin, ".message h1.win", "You won!")
      assert has_element?(erin, ".message .wait", "Waiting for the table")
      refute has_element?(erin, ".slip")

      assert has_element?(bob, ".message h1", "Erin won")
      assert has_element?(bob, ".message .lead", "Last one left")
      assert has_element?(bob, ".message .wait", "Waiting for the table")
    end

    test "the result survives the winner leaving", %{erin: erin} do
      :ok = Room.start_game()

      tweak_room(erin, fn state ->
        %{
          state
          | phase: :finished,
            winner: "bob",
            people: Map.delete(state.people, "bob"),
            order: List.delete(state.order, "bob")
        }
      end)

      assert has_element?(erin, ".message h1", "Someone won")
    end
  end

  test "a late joiner waits in the queue for this game to end", %{conn: conn} do
    :ok = Room.start_game()
    {:ok, gus, _html} = live(phone(conn, "gus"), ~p"/")
    gus |> form("#join", %{name: "Gus"}) |> render_submit()

    assert has_element?(gus, ".message h1", "You're #1 in line.")
    assert has_element?(gus, ".message .wait", "Waiting for this game to end")
  end
end
