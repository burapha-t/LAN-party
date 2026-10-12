defmodule LanParty.RoomTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Room
  alias LanParty.Uno.{Card, Rules}

  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    topic = Atom.to_string(name)
    start_supervised!({Room, name: name, topic: topic, grace_ms: 50, game_opts: [deck: deck_starting_with(2, 5), first_player: "t1"]})
    Room.subscribe(topic)
    %{room: name}
  end

  # A stand-in for a LiveView page: a process that lives until killed.
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  defp join!(room, token, name), do: :ok = Room.join(room, token, name, page())

  describe "joining" do
    test "people join in arrival order and every page hears about it", %{room: room} do
      join!(room, "t1", "Alice")
      join!(room, "t2", "Bob")

      state = Room.get_state(room)
      assert state.order == ["t1", "t2"]
      assert Room.name(state, "t2") == "Bob"
      assert_receive {:party_updated, %{order: ["t1", "t2"]}}
    end

    test "names are trimmed, required, and at most 20 characters", %{room: room} do
      assert Room.join(room, "t1", "   ", page()) == {:error, :invalid_name}
      assert Room.join(room, "t1", String.duplicate("x", 21), page()) == {:error, :invalid_name}
      assert Room.join(room, "t1", "  Alice ", page()) == :ok
      assert Room.name(Room.get_state(room), "t1") == "Alice"
    end

    test "a name that differs only by case or spaces is taken", %{room: room} do
      join!(room, "t1", "Alice")
      assert Room.join(room, "t2", " alice ", page()) == {:error, :name_taken}
    end

    test "the same browser can't join twice", %{room: room} do
      join!(room, "t1", "Alice")
      assert Room.join(room, "t1", "Alicia", page()) == {:error, :already_joined}
    end
  end

  describe "picking a game" do
    test "only playable games, and only from the picker", %{room: room} do
      assert Room.get_state(room).phase == :picking
      assert Room.pick_game(room, :quiplash) == {:error, :not_playable}
      assert Room.pick_game(room, :uno) == :ok

      state = Room.get_state(room)
      assert state.game_id == :uno
      assert state.phase == :lobby
      assert Room.pick_game(room, :uno) == {:error, :not_now}
    end

    test "seats everyone in arrival order, up to 8; the rest queue", %{room: room} do
      for i <- 1..9, do: join!(room, "t#{i}", "P#{i}")
      :ok = Room.pick_game(room, :uno)

      state = Room.get_state(room)
      assert Room.seated(state) == Enum.map(1..8, &"t#{&1}")
      assert Room.queued(state) == ["t9"]
    end

    test "Change game goes back to the picker, from the lobby only", %{room: room} do
      assert Room.change_game(room) == {:error, :not_now}
      :ok = Room.pick_game(room, :uno)
      assert Room.change_game(room) == :ok

      state = Room.get_state(room)
      assert state.phase == :picking
      assert state.game_id == nil
    end
  end

  describe "the UNO lobby" do
    setup %{room: room} do
      :ok = Room.pick_game(room, :uno)
    end

    test "a 9th person waits in the queue", %{room: room} do
      for i <- 1..9, do: join!(room, "t#{i}", "P#{i}")
      assert Room.queued(Room.get_state(room)) == ["t9"]
    end

    test "settings accept only known house rules with true/false", %{room: room} do
      :ok = Room.update_settings(room, %{jump_in: true, stack_plus2: "yes", cheat: true})

      settings = Room.get_state(room).settings
      assert settings.jump_in
      refute settings.stack_plus2
      refute Map.has_key?(settings, :cheat)
    end

    test "starting needs 2 seated players", %{room: room} do
      join!(room, "t1", "Alice")
      assert Room.start_game(room) == {:error, :not_enough_players}
      join!(room, "t2", "Bob")
      assert Room.start_game(room) == :ok

      state = Room.get_state(room)
      assert state.phase == :playing
      assert state.game.players == ["t1", "t2"]
      assert Room.update_settings(room, %{jump_in: true}) == {:error, :not_in_lobby}
      assert Room.change_game(room) == {:error, :not_now}
    end

    test "someone joining mid-round is queued", %{room: room} do
      join!(room, "t1", "Alice")
      join!(room, "t2", "Bob")
      :ok = Room.start_game(room)
      join!(room, "t3", "Carol")

      assert Room.queued(Room.get_state(room)) == ["t3"]
    end
  end

  describe "a round" do
    # The fixed deck gives t1 red 0, 1, 2, 3, 4, 6, 7 (ids 1, 2, 3, 4, 5, 7, 8) and t2 ids 9–15;
    # red 5 (id 6) starts the pile and t1 goes first.
    setup %{room: room} do
      :ok = Room.pick_game(room, :uno)
      join!(room, "t1", "Alice")
      join!(room, "t2", "Bob")
      :ok = Room.start_game(room)
    end

    test "actions go to the rules; errors come back to the caller only", %{room: room} do
      assert Room.act(room, "t2", {:play, 9, %{}}) == {:error, :not_your_turn}
      assert Room.act(room, "t1", {:play, 2, %{}}) == :ok
      assert Rules.top_card(Room.get_state(room).game).id == 2
    end

    test "a win finishes the round", %{room: room} do
      :sys.replace_state(room, fn state ->
        put_in(state.game.hands["t1"], [%Card{id: 2, color: :red, value: 1}])
      end)

      assert Room.act(room, "t1", {:play, 2, %{}}) == :ok
      state = Room.get_state(room)
      assert state.phase == :finished
      assert state.winner == "t1"
    end

    test "table controls go to the game's rules: draw for player takes 1 to 10 cards", %{room: room} do
      assert Room.table_act(room, {:draw_for, "t2", 0}) == {:error, :bad_amount}
      assert Room.table_act(room, {:draw_for, "t2", 11}) == {:error, :bad_amount}
      assert Room.table_act(room, {:draw_for, "t2", 2}) == :ok
      assert length(Room.get_state(room).game.hands["t2"]) == 9
    end

    test "a table control the game doesn't know is refused, and the Room keeps going", %{room: room} do
      assert Room.table_act(room, :roll) == {:error, :unknown_action}
      assert Room.get_state(room).phase == :playing
    end

    test "back to the lobby keeps seats, fills free ones from the queue, keeps settings", %{room: room} do
      join!(room, "t3", "Carol")
      assert Room.back_to_lobby(room) == :ok

      state = Room.get_state(room)
      assert state.phase == :lobby
      assert state.game == nil
      assert Room.seated(state) == ["t1", "t2", "t3"]
      assert Room.back_to_lobby(room) == {:error, :not_now}
    end

    test "actions outside a round are refused", %{room: room} do
      :ok = Room.back_to_lobby(room)
      assert Room.act(room, "t1", :draw) == {:error, :not_playing}
      assert Room.table_act(room, {:draw_for, "t2", 2}) == {:error, :not_now}
    end
  end
end
