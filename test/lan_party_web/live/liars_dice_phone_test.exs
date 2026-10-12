defmodule LanPartyWeb.LiarsDicePhoneTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers, only: [sync: 1, restart_room: 0]

  alias LanParty.Room

  # Every roll: five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)
  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})

  # Erin (this phone) and Bob, in the Liar's Dice lobby.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, fn state -> %{state | game_opts: [roller: &fixed/1]} end)
    {:ok, erin, _html} = live(phone(conn, "erin"), ~p"/")
    erin |> form("#join", %{name: "Erin"}) |> render_submit()
    :ok = Room.join("bob", "Bob", page())
    :ok = Room.pick_game(:liars_dice)
    sync(erin)
    %{erin: erin}
  end

  # Change the Room behind the phone's back, then let the phone re-render.
  defp tweak_room(view, fun) do
    :sys.replace_state(Room, fun)
    send(view.pid, {:party_updated, Room.get_state()})
    sync(view)
  end

  test "the phone follows the table to Liar's Dice and waits in the lobby", %{erin: erin} do
    assert render(erin) =~ "Waiting for the table to start"
  end

  test "Start game: your 5 dice, sorted, rolling in; no buttons", %{erin: erin} do
    :ok = Room.start_game()
    sync(erin)

    for {value, index} <- Enum.with_index([1, 1, 3, 4, 6]) do
      assert has_element?(erin, "#die-1-#{index}.die.v#{value}.rolling")
    end

    refute has_element?(erin, "#die-1-5")
    assert has_element?(erin, ".dice-hint", "Bids are out loud. Keep your dice hidden.")
    refute has_element?(erin, "button")
  end

  test "a phone shows only its own dice", %{erin: erin} do
    :ok = Room.start_game()
    tweak_room(erin, fn state -> put_in(state.game.dice["bob"], [2, 2, 2, 2, 2]) end)

    assert has_element?(erin, ".die.v1")
    refute has_element?(erin, ".die.v2")
  end

  test "a phone opened mid-game shows its dice already landed; the next roll animates", %{
    conn: conn
  } do
    :ok = Room.start_game()
    {:ok, again, _html} = live(phone(conn, "erin"), ~p"/")

    assert has_element?(again, "#die-1-0")
    refute has_element?(again, ".die.rolling")

    :ok = Room.table_act(:roll)
    sync(again)
    assert has_element?(again, "#die-2-0.rolling")
    refute has_element?(again, "#die-1-0")
  end

  test "a phone opened mid-game still animates the first roll of the next game", %{conn: conn} do
    :ok = Room.start_game()
    :ok = Room.table_act(:roll)
    {:ok, again, _html} = live(phone(conn, "erin"), ~p"/")

    :ok = Room.back_to_lobby()
    sync(again)
    :ok = Room.start_game()
    sync(again)
    assert has_element?(again, "#die-1-0.rolling")
  end

  test "a count lights up the face and the 1s and dims the rest; Roll clears it", %{erin: erin} do
    :ok = Room.start_game()
    :ok = Room.table_act({:count, 4})
    sync(erin)

    assert has_element?(erin, ".counting", "Counting 4s")
    assert has_element?(erin, ".stage-hint", "1s are wild. Show your phone.")
    assert has_element?(erin, "#die-1-0.v1.lit")
    assert has_element?(erin, "#die-1-1.v1.lit")
    assert has_element?(erin, "#die-1-2.v3.dim")
    assert has_element?(erin, "#die-1-3.v4.lit")
    assert has_element?(erin, "#die-1-4.v6.dim")
    refute has_element?(erin, ".dice-hint")

    :ok = Room.table_act(:roll)
    sync(erin)
    refute has_element?(erin, ".die.lit")
    refute has_element?(erin, ".die.dim")
    refute has_element?(erin, ".counting")
  end

  test "when the table takes a die, the highest goes and the rest stay put", %{erin: erin} do
    :ok = Room.start_game()
    :ok = Room.table_act({:take_die, "erin"})
    sync(erin)

    assert has_element?(erin, "#die-1-3.v4")
    refute has_element?(erin, "#die-1-4")
  end

  test "with no dice left, you're out", %{erin: erin} do
    :ok = Room.join("carol", "Carol", page())
    :ok = Room.start_game()
    for _ <- 1..5, do: :ok = Room.table_act({:take_die, "erin"})
    sync(erin)

    assert has_element?(erin, ".message h1", "You're out.")

    assert has_element?(
             erin,
             ".message .lead",
             "No dice left. Watch the rest of the game on the table."
           )

    assert has_element?(erin, ".message .wait", "Waiting for the game to end")
  end

  test "the last one with dice wins; the others see who", %{erin: erin, conn: conn} do
    {:ok, bob, _html} = live(phone(conn, "bob"), ~p"/")
    :ok = Room.start_game()
    for _ <- 1..5, do: :ok = Room.table_act({:take_die, "bob"})
    sync(erin)
    sync(bob)

    assert has_element?(erin, ".message h1.win", "You won!")
    assert has_element?(erin, ".message .dice .die.v6")
    refute has_element?(erin, ".message .die.rolling")
    assert has_element?(erin, ".message .wait", "Waiting for the table")

    assert has_element?(bob, ".message h1", "Erin won")
    assert has_element?(bob, ".message .lead", "Last one with dice")
  end

  test "the result survives the winner leaving", %{erin: erin} do
    :ok = Room.start_game()
    for _ <- 1..5, do: :ok = Room.table_act({:take_die, "erin"})
    sync(erin)
    assert has_element?(erin, ".message h1", "Bob won")

    tweak_room(erin, fn state ->
      %{state | people: Map.delete(state.people, "bob"), order: List.delete(state.order, "bob")}
    end)

    assert has_element?(erin, ".message h1", "Someone won")
  end

  test "a late joiner waits in the queue for this game to end", %{conn: conn} do
    :ok = Room.start_game()
    {:ok, gus, _html} = live(phone(conn, "gus"), ~p"/")
    gus |> form("#join", %{name: "Gus"}) |> render_submit()

    assert has_element?(gus, ".message h1", "You're #1 in line.")
    assert has_element?(gus, ".message .wait", "Waiting for this game to end")
  end
end
