defmodule LanParty.RoomUndercoverTest do
  use ExUnit.Case, async: true

  alias LanParty.Room
  alias LanParty.Undercover.Rules

  # Made-up pairs and a fixed shuffle, so no test depends on pairs.txt.
  @pairs [{"Alpha", "Beta"}, {"Cedar", "Dune"}, {"Ember", "Fjord"}]
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Alice and Bob in the Undercover lobby; Carol joins in the tests that need her.
  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    topic = Atom.to_string(name)

    start_supervised!(
      {Room, name: name, topic: topic, grace_ms: 50, game_opts: [pairs: @pairs, shuffle: & &1]}
    )

    Room.subscribe(topic)

    pages = Map.new(["t1", "t2", "t3"], &{&1, page()})
    :ok = Room.join(name, "t1", "Alice", pages["t1"])
    :ok = Room.join(name, "t2", "Bob", pages["t2"])
    :ok = Room.pick_game(name, :undercover)
    %{room: name, pages: pages}
  end

  defp join_carol(%{room: room, pages: pages}),
    do: :ok = Room.join(room, "t3", "Carol", pages["t3"])

  # Close a player's page and wait past the grace period, so they're kicked.
  defp kick(page) do
    Process.exit(page, :kill)
    Process.sleep(80)
  end

  test "Undercover is playable, and Start needs 3 seated players", %{room: room} = context do
    assert Room.get_state(room).game_id == :undercover
    assert Room.start_game(room) == {:error, :not_enough_players}
    assert Room.get_state(room).phase == :lobby

    join_carol(context)
    assert Room.start_game(room) == :ok

    state = Room.get_state(room)
    assert state.phase == :playing
    assert %Rules{players: ["t1", "t2", "t3"], deal: 1, undercovers: 1} = state.game
    assert state.game.words == %{"t1" => "Beta", "t2" => "Alpha", "t3" => "Alpha"}
  end

  test "UNO and Liar's Dice still start with 2", %{room: room} do
    :ok = Room.change_game(room)
    :ok = Room.pick_game(room, :liars_dice)
    assert Room.start_game(room) == :ok
  end

  test "Reroll goes to the Undercover rules, and every page hears about it",
       %{room: room} = context do
    join_carol(context)
    :ok = Room.start_game(room)

    assert Room.table_act(room, :reroll) == :ok
    assert_receive {:party_updated, %{game: %Rules{deal: 2}}}
    assert Room.get_state(room).game.words == %{"t1" => "Dune", "t2" => "Cedar", "t3" => "Cedar"}
    assert Room.table_act(room, {:take_die, "t1"}) == {:error, :unknown_action}
  end

  test "phones have no moves", %{room: room} = context do
    join_carol(context)
    :ok = Room.start_game(room)
    assert Room.act(room, "t1", :reroll) == {:error, :no_actions}
  end

  test "Reroll is refused outside a game", %{room: room} do
    assert Room.table_act(room, :reroll) == {:error, :not_now}
  end

  test "a kick during a deal takes the player's word out and keeps the dealt count; the game goes on",
       %{room: room, pages: pages} = context do
    join_carol(context)
    :ok = Room.start_game(room)
    kick(pages["t2"])

    state = Room.get_state(room)
    assert state.phase == :playing
    assert state.game.players == ["t1", "t3"]
    assert state.game.words == %{"t1" => "Beta", "t3" => "Alpha"}
    assert state.game.undercovers == 1

    assert Room.table_act(room, :reroll) == :ok
    assert Room.get_state(room).game.words == %{"t1" => "Dune", "t3" => "Cedar"}
  end

  test "when a kick leaves one player, that player wins", %{room: room, pages: pages} = context do
    join_carol(context)
    :ok = Room.start_game(room)
    kick(pages["t2"])
    kick(pages["t3"])

    state = Room.get_state(room)
    assert state.phase == :finished
    assert state.winner == "t1"
    assert Room.table_act(room, :reroll) == {:error, :not_now}
  end

  test "after Play again, the next game starts again from deal 1 and the first pair",
       %{room: room} = context do
    join_carol(context)
    :ok = Room.start_game(room)
    :ok = Room.table_act(room, :reroll)
    :ok = Room.back_to_lobby(room)
    :ok = Room.start_game(room)

    game = Room.get_state(room).game
    assert game.deal == 1
    assert game.words["t2"] == "Alpha"
  end
end
