defmodule LanParty.Room do
  @moduledoc """
  The platform state for the night: who has joined, the game the table picked, seats, queue, house
  rules, phases, disconnects and kicks. Knows nothing about cards: UNO actions go to
  `LanParty.Uno.Rules`. Calls are handled one at a time in arrival order, which is what makes
  "first jump-in wins" automatic. See docs/uno/design.md §4–5.
  """
  use GenServer

  alias LanParty.Games
  alias LanParty.Uno.Rules

  @max_seats 8
  @max_name 20
  @setting_keys Map.keys(Rules.default_settings())

  ## Client API. `server` defaults to the app-wide Room.

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def subscribe(topic \\ "party"), do: Phoenix.PubSub.subscribe(LanParty.PubSub, topic)

  def get_state(server \\ __MODULE__), do: GenServer.call(server, :get_state)

  def join(server \\ __MODULE__, token, name, pid) when is_binary(name),
    do: GenServer.call(server, {:join, token, name, pid})

  def attach(server \\ __MODULE__, token, pid), do: GenServer.call(server, {:attach, token, pid})
  def act(server \\ __MODULE__, token, action), do: GenServer.call(server, {:act, token, action})
  def pick_game(server \\ __MODULE__, game_id), do: GenServer.call(server, {:pick_game, game_id})
  def change_game(server \\ __MODULE__), do: GenServer.call(server, :change_game)

  def update_settings(server \\ __MODULE__, settings),
    do: GenServer.call(server, {:update_settings, settings})

  def start_game(server \\ __MODULE__), do: GenServer.call(server, :start_game)
  def draw_for(server \\ __MODULE__, token, n), do: GenServer.call(server, {:draw_for, token, n})
  def back_to_lobby(server \\ __MODULE__), do: GenServer.call(server, :back_to_lobby)

  ## Reading a state (pure helpers for the LiveViews)

  def seated(state), do: Enum.filter(state.order, &(state.people[&1].status == :seated))
  def queued(state), do: Enum.filter(state.order, &(state.people[&1].status == :queued))
  def away?(person), do: MapSet.size(person.pids) == 0
  def name(state, token), do: get_in(state, [:people, token, :name])

  ## Server

  @impl true
  def init(opts) do
    {:ok,
     %{
       topic: Keyword.get(opts, :topic, "party"),
       grace_ms: Keyword.get(opts, :grace_ms, Application.get_env(:lan_party, :grace_ms, 30_000)),
       game_opts: Keyword.get(opts, :game_opts, []),
       game_id: nil,
       phase: :picking,
       people: %{},
       order: [],
       monitors: %{},
       kicked: %{},
       settings: Rules.default_settings(),
       game: nil,
       winner: nil
     }}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call({:join, token, name, pid}, _from, state) do
    name = String.trim(name)

    cond do
      Map.has_key?(state.people, token) ->
        {:reply, {:error, :already_joined}, state}

      name == "" or String.length(name) > @max_name ->
        {:reply, {:error, :invalid_name}, state}

      name_taken?(state, name) ->
        {:reply, {:error, :name_taken}, state}

      true ->
        person = %{name: name, status: join_status(state), pids: MapSet.new(), away_ref: nil}

        state =
          %{
            state
            | people: Map.put(state.people, token, person),
              order: state.order ++ [token],
              kicked: Map.delete(state.kicked, token)
          }
          |> watch(token, pid)

        {:reply, :ok, broadcast(state)}
    end
  end

  def handle_call({:attach, token, pid}, _from, state) do
    if Map.has_key?(state.people, token) do
      state = state |> watch(token, pid) |> update_person(token, &%{&1 | away_ref: nil})
      {:reply, :ok, broadcast(state)}
    else
      {:reply, {:error, :unknown_player}, state}
    end
  end

  def handle_call({:act, token, action}, _from, %{phase: :playing} = state) do
    case Rules.apply_action(state.game, token, action) do
      {:ok, game} -> {:reply, :ok, state |> put_game(game) |> broadcast()}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:act, _token, _action}, _from, state), do: {:reply, {:error, :not_playing}, state}

  def handle_call({:pick_game, game_id}, _from, %{phase: :picking} = state) do
    if Games.playable?(game_id),
      do: {:reply, :ok, %{state | game_id: game_id, phase: :lobby} |> reseat() |> broadcast()},
      else: {:reply, {:error, :not_playable}, state}
  end

  def handle_call({:pick_game, _game_id}, _from, state), do: {:reply, {:error, :not_now}, state}

  def handle_call(:change_game, _from, %{phase: :lobby} = state),
    do: {:reply, :ok, broadcast(%{state | game_id: nil, phase: :picking})}

  def handle_call(:change_game, _from, state), do: {:reply, {:error, :not_now}, state}

  def handle_call({:update_settings, settings}, _from, %{phase: :lobby} = state) do
    clean = for {key, value} <- settings, key in @setting_keys, is_boolean(value), into: %{}, do: {key, value}
    {:reply, :ok, broadcast(%{state | settings: Map.merge(state.settings, clean)})}
  end

  def handle_call({:update_settings, _settings}, _from, state), do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call(:start_game, _from, %{phase: :lobby} = state) do
    case seated(state) do
      [_, _ | _] = players ->
        game = Rules.new(players, state.settings, state.game_opts)
        {:reply, :ok, broadcast(%{state | phase: :playing, game: game, winner: nil})}

      _fewer ->
        {:reply, {:error, :not_enough_players}, state}
    end
  end

  def handle_call(:start_game, _from, state), do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:draw_for, token, n}, _from, %{phase: :playing} = state)
      when is_integer(n) and n in 1..10 do
    case Rules.draw_for(state.game, token, n) do
      {:ok, game} -> {:reply, :ok, broadcast(%{state | game: game})}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:draw_for, _token, _n}, _from, state), do: {:reply, {:error, :not_now}, state}

  def handle_call(:back_to_lobby, _from, %{phase: phase} = state) when phase in [:playing, :finished] do
    state = %{state | phase: :lobby, game: nil, winner: nil} |> fill_seats()
    {:reply, :ok, broadcast(state)}
  end

  def handle_call(:back_to_lobby, _from, state), do: {:reply, {:error, :not_now}, state}

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, _monitors} -> {:noreply, state}
      {{token, pid}, monitors} -> {:noreply, page_closed(%{state | monitors: monitors}, token, pid)}
    end
  end

  # Only the newest timer counts: coming back clears `away_ref`, so an old timer is ignored.
  def handle_info({:grace_expired, token, ref}, state) do
    case state.people[token] do
      %{away_ref: ^ref} -> {:noreply, state |> kick(token) |> broadcast()}
      _other -> {:noreply, state}
    end
  end

  ## Helpers

  defp join_status(%{phase: :picking}), do: :seated
  defp join_status(%{phase: :lobby} = state), do: if(length(seated(state)) < @max_seats, do: :seated, else: :queued)
  defp join_status(_state), do: :queued

  defp name_taken?(state, name) do
    wanted = String.downcase(name)
    Enum.any?(state.people, fn {_token, person} -> String.downcase(person.name) == wanted end)
  end

  # Monitor a page so the Room hears when it closes.
  defp watch(state, token, pid) do
    if MapSet.member?(state.people[token].pids, pid) do
      state
    else
      ref = Process.monitor(pid)

      state
      |> update_person(token, &%{&1 | pids: MapSet.put(&1.pids, pid)})
      |> Map.update!(:monitors, &Map.put(&1, ref, {token, pid}))
    end
  end

  defp put_game(state, game) do
    case Rules.winner(game) do
      nil -> %{state | game: game}
      winner -> %{state | game: game, phase: :finished, winner: winner}
    end
  end

  # Picking a game: everyone, in arrival order, up to 8 seats.
  defp reseat(state) do
    state.order
    |> Enum.with_index()
    |> Enum.reduce(state, fn {token, index}, acc ->
      update_person(acc, token, &%{&1 | status: if(index < @max_seats, do: :seated, else: :queued)})
    end)
  end

  # Back to the lobby: seated players keep their seats; queued players fill free ones.
  defp fill_seats(state) do
    free = max(@max_seats - length(seated(state)), 0)

    state
    |> queued()
    |> Enum.take(free)
    |> Enum.reduce(state, fn token, acc -> update_person(acc, token, &%{&1 | status: :seated}) end)
  end

  defp update_person(state, token, fun), do: %{state | people: Map.update!(state.people, token, fun)}

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(LanParty.PubSub, state.topic, {:party_updated, state})
    state
  end

  defp page_closed(state, token, pid) do
    case state.people[token] do
      nil ->
        state

      person ->
        pids = MapSet.delete(person.pids, pid)

        if MapSet.size(pids) == 0 do
          ref = make_ref()
          Process.send_after(self(), {:grace_expired, token, ref}, state.grace_ms)
          state |> update_person(token, &%{&1 | pids: pids, away_ref: ref}) |> broadcast()
        else
          update_person(state, token, &%{&1 | pids: pids})
        end
    end
  end

  # Forgotten for the night. If they were in a round, the rules take them out of it.
  defp kick(state, token) do
    person = state.people[token]

    state = %{
      state
      | people: Map.delete(state.people, token),
        order: List.delete(state.order, token),
        kicked: Map.put(state.kicked, token, person.name)
    }

    cond do
      state.phase == :playing and person.status == :seated -> remove_from_round(state, token)
      # A seat freed in the lobby goes straight to the first person in the queue.
      state.phase == :lobby -> fill_seats(state)
      true -> state
    end
  end

  # Last player left wins (CLAUDE.md "Disconnects").
  defp remove_from_round(state, token) do
    game = Rules.remove_player(state.game, token)

    case game.players do
      [last] -> %{state | game: game, phase: :finished, winner: last}
      _more -> %{state | game: game}
    end
  end
end
