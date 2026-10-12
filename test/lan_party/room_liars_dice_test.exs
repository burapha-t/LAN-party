defmodule LanParty.RoomLiarsDiceTest do
  use ExUnit.Case, async: true

  alias LanParty.Room
  alias LanParty.LiarsDice.Rules

  # Every roll: five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Alice, Bob and Carol in the Liar's Dice lobby.
  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    topic = Atom.to_string(name)

    start_supervised!(
      {Room, name: name, topic: topic, grace_ms: 50, game_opts: [roller: &fixed/1]}
    )

    Room.subscribe(topic)

    pages = Map.new(["t1", "t2", "t3"], &{&1, page()})
    :ok = Room.join(name, "t1", "Alice", pages["t1"])
    :ok = Room.join(name, "t2", "Bob", pages["t2"])
    :ok = Room.join(name, "t3", "Carol", pages["t3"])
    :ok = Room.pick_game(name, :liars_dice)
    %{room: name, pages: pages}
  end

  # Close a player's page and wait past the grace period, so they're kicked.
  defp kick(page) do
    Process.exit(page, :kill)
    Process.sleep(80)
  end

  defp set_dice(room, dice) do
    :sys.replace_state(room, fn state ->
      put_in(state.game.dice, Map.merge(state.game.dice, dice))
    end)
  end

  test "Start game gives every seated player 5 dice", %{room: room} do
    assert Room.start_game(room) == :ok

    state = Room.get_state(room)
    assert state.phase == :playing
    assert %Rules{players: ["t1", "t2", "t3"], roll: 1, face: nil} = state.game
    assert state.game.dice["t2"] == [1, 1, 3, 4, 6]
  end

  test "table controls go to the Liar's Dice rules, and every page hears about them", %{
    room: room
  } do
    :ok = Room.start_game(room)

    assert Room.table_act(room, {:count, 4}) == :ok
    assert_receive {:party_updated, %{game: %Rules{face: 4}}}
    assert Room.table_act(room, :roll) == :ok
    assert_receive {:party_updated, %{game: %Rules{face: nil, roll: 2}}}
    assert Room.table_act(room, {:count, 1}) == {:error, :bad_face}
    assert Room.table_act(room, {:take_die, "t1"}) == :ok
    assert length(Room.get_state(room).game.dice["t1"]) == 4
  end

  test "phones have no moves", %{room: room} do
    :ok = Room.start_game(room)
    assert Room.act(room, "t1", :roll) == {:error, :no_actions}
  end

  test "table controls are refused outside a game", %{room: room} do
    assert Room.table_act(room, :roll) == {:error, :not_now}
  end

  test "taking the last die of the second-to-last player finishes the game", %{room: room} do
    :ok = Room.start_game(room)
    set_dice(room, %{"t1" => [2], "t3" => []})

    assert Room.table_act(room, {:take_die, "t1"}) == :ok
    state = Room.get_state(room)
    assert state.phase == :finished
    assert state.winner == "t2"
    assert Room.table_act(room, :roll) == {:error, :not_now}
  end

  test "a kick that leaves one player with dice finishes the game", %{room: room, pages: pages} do
    :ok = Room.start_game(room)
    set_dice(room, %{"t3" => []})
    kick(pages["t2"])

    state = Room.get_state(room)
    assert state.phase == :finished
    assert state.winner == "t1"
  end

  test "kicking an out player doesn't end the game", %{room: room, pages: pages} do
    :ok = Room.start_game(room)
    set_dice(room, %{"t3" => []})
    kick(pages["t3"])

    state = Room.get_state(room)
    assert state.phase == :playing
    assert state.game.players == ["t1", "t2"]
  end

  test "after Play again, the next game starts again from roll 1", %{room: room} do
    :ok = Room.start_game(room)
    :ok = Room.table_act(room, :roll)
    :ok = Room.back_to_lobby(room)
    :ok = Room.start_game(room)

    assert Room.get_state(room).game.roll == 1
  end
end
