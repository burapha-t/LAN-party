defmodule LanPartyWeb.PlayerLive do
  @moduledoc """
  The phone at `/`: join once per night, wait for the table to pick a game, then that game's phone
  screens. See docs/uno/design.md §2 and §4. Markup follows docs/mockups/platform/phone/; the header
  bar follows docs/mockups/redesign/.
  """
  use LanPartyWeb, :live_view

  import LanPartyWeb.LobbyComponents

  alias LanParty.{Games, Room}

  @impl true
  def mount(_params, %{"player_token" => token}, socket) do
    if connected?(socket) do
      Room.subscribe()
      Process.monitor(Room)
      Room.attach(token, self())
    end

    room = Room.get_state()

    # A kicked player coming back finds their old name already filled in.
    {:ok, socket |> assign(token: token, error: nil, name: Map.get(room.kicked, token, "")) |> assign_room(room)}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    case Room.join(socket.assigns.token, name, self()) do
      :ok -> {:noreply, assign(socket, error: nil)}
      {:error, :already_joined} -> {:noreply, socket}
      {:error, :name_taken} -> {:noreply, assign(socket, error: "That name is taken. Try another.", name: name)}
      {:error, _reason} -> {:noreply, assign(socket, error: "Enter a name of up to 20 characters.", name: name)}
    end
  end

  @impl true
  def handle_info({:party_updated, room}, socket), do: {:noreply, assign_room(socket, room)}

  # The Room crashed and restarted empty: reload so this phone lands on the join screen.
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, redirect(socket, to: ~p"/")}

  defp assign_room(socket, room) do
    me = room.people[socket.assigns.token]

    # Removed by the table while this page was open: fill in the old name, as a reload would.
    socket =
      if socket.assigns[:me] && !me,
        do: assign(socket, name: Map.get(room.kicked, socket.assigns.token, "")),
        else: socket

    assign(socket,
      room: room,
      me: me,
      kicked?: Map.has_key?(room.kicked, socket.assigns.token),
      removed?: MapSet.member?(room.removed, socket.assigns.token),
      brand: if(me && room.game_id, do: Games.name(room.game_id), else: "LAN Party")
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="phone">
      <header class="bar">
        <span :if={@me} class="me">
          <.avatar room={@room} token={@token} /><span>Playing as <strong>{@me.name}</strong></span>
        </span>
        <span :if={!@me}></span>
        <span class="wordmark">{@brand}</span>
      </header>

      <div :if={!@me} class="message">
        <p :if={@kicked? and @removed?} class="notice">
          The table removed you from the game. Join again for the next game.
        </p>
        <p :if={@kicked? and !@removed?} class="notice">
          You were away too long and left the game. Join again for the next game.
        </p>
        <form class="join" id="join" phx-submit="join">
          <label for="name">What's your name?</label>
          <input
            class="field"
            id="name"
            name="name"
            autocomplete="nickname"
            maxlength="20"
            placeholder="Your name"
            value={@name}
            aria-invalid={@error && "true"}
            aria-describedby={@error && "name-error"}
          />
          <p :if={@error} class="field-error" id="name-error">{@error}</p>
          <button class="btn" type="submit">Join</button>
        </form>
      </div>

      <div :if={@me && is_nil(@room.game_id)} class="message">
        <h1>You're in, {@me.name}.</h1>
        <a class="wait">Waiting for the table to pick a game</a>
        <div>
          <p class="people-label">Here now</p>
          <ul class="people">
            <li :for={token <- @room.order} class={token == @token && "you"}>{Room.name(@room, token)}{if token == @token, do: " (you)"}</li>
          </ul>
        </div>
      </div>

      <.live_component
        :if={@me && @room.game_id == :uno}
        module={LanPartyWeb.Uno.PlayerComponent}
        id="uno-phone"
        room={@room}
        token={@token}
      />

      <.live_component
        :if={@me && @room.game_id == :liars_dice}
        module={LanPartyWeb.LiarsDice.PlayerComponent}
        id="liars-dice-phone"
        room={@room}
        token={@token}
      />

      <div
        id="reconnect"
        style="display: none"
        phx-disconnected={JS.show(to: "#reconnect")}
        phx-connected={JS.hide(to: "#reconnect")}
      >
        <div class="scrim"></div>
        <div class="reconnect" role="status">
          <strong>Reconnecting…</strong><span>Your phone lost the connection. Keep this page open.</span>
        </div>
      </div>
    </main>
    """
  end
end
