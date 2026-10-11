defmodule LanParty.RoomDisconnectTest do
  use ExUnit.Case, async: true

  alias LanParty.Room

  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    start_supervised!({Room, name: name, topic: Atom.to_string(name), grace_ms: 50})
    %{room: name}
  end

  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Close a page and give the Room a moment to notice.
  defp close(pid) do
    Process.exit(pid, :kill)
    Process.sleep(10)
  end

  defp person(room, token), do: Room.get_state(room).people[token]

  test "a closed page marks the player away; after the grace period they're kicked", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    close(tab)

    assert Room.away?(person(room, "t1"))

    Process.sleep(80)
    state = Room.get_state(room)
    refute Map.has_key?(state.people, "t1")
    assert state.order == []
    assert MapSet.member?(state.kicked, "t1")
  end

  test "coming back within the grace period keeps the seat", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    close(tab)
    :ok = Room.attach(room, "t1", page())

    Process.sleep(80)
    refute Room.away?(person(room, "t1"))
  end

  test "closing one of two tabs doesn't make you away", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    :ok = Room.attach(room, "t1", page())
    close(tab)

    Process.sleep(80)
    refute Room.away?(person(room, "t1"))
  end

  test "a kicked player who joins again is no longer marked as kicked", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    close(tab)
    Process.sleep(80)

    :ok = Room.join(room, "t1", "Alice", page())
    refute MapSet.member?(Room.get_state(room).kicked, "t1")
  end

  test "attaching a browser the Room doesn't know fails", %{room: room} do
    assert Room.attach(room, "nobody", page()) == {:error, :unknown_player}
  end

  describe "during a round" do
    setup %{room: room} do
      tabs = %{"t1" => page(), "t2" => page(), "t3" => page()}
      for token <- ["t1", "t2", "t3"], do: :ok = Room.join(room, token, token, tabs[token])
      :ok = Room.pick_game(room, :uno)
      :ok = Room.start_game(room)
      %{tabs: tabs}
    end

    test "a kicked player leaves the round and play goes on", %{room: room, tabs: tabs} do
      close(tabs["t3"])
      Process.sleep(80)

      state = Room.get_state(room)
      assert state.phase == :playing
      assert state.game.players == ["t1", "t2"]
    end

    test "when one player is left, they win", %{room: room, tabs: tabs} do
      close(tabs["t2"])
      close(tabs["t3"])
      Process.sleep(80)

      state = Room.get_state(room)
      assert state.phase == :finished
      assert state.winner == "t1"
    end
  end
end
