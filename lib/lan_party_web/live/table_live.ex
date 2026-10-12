defmodule LanPartyWeb.TableLive do
  @moduledoc """
  The table at `/table`: "Select the game", then that game's table screens. Any number of table
  devices can be open; all show the same thing and all can use the controls.
  Markup follows docs/mockups/table/.
  """
  use LanPartyWeb, :live_view

  alias LanParty.{Games, Room}
  alias LanParty.Uno.Card
  import LanPartyWeb.Uno.Components
  alias LanPartyWeb.LiarsDice.Components, as: Dice

  @spines %{
    liars_dice: "--sc:#8a3340;--h:84%;--w:max(46px,5.2vw)",
    quiplash: "--sc:#2f7a7e;--h:92%;--w:max(46px,4.4vw)",
    paranoia: "--sc:#63428a;--h:76%;--w:max(46px,4.8vw)",
    who_wrote_it: "--sc:#96742c;--h:88%;--w:max(46px,4.2vw)",
    love_letter: "--sc:#9a4466;--h:74%;--w:max(46px,4.4vw)",
    never_have_i_ever: "--sc:#3f5590;--h:96%;--w:max(46px,5.6vw)",
    killer: "--sc:#355a45;--h:80%;--w:max(46px,4.4vw)"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Room.subscribe()
      Process.monitor(Room)
    end

    {:ok, socket |> assign(selected: nil) |> assign_room(Room.get_state())}
  end

  # Tapping a box only selects it on this device; the side panel's Play button picks the game.
  @impl true
  def handle_event("select_game", %{"id" => id}, socket) do
    game = Enum.find(Games.all(), &(&1.playable? and Atom.to_string(&1.id) == id))
    {:noreply, assign(socket, selected: game && game.id)}
  end

  def handle_event("pick_game", %{"id" => id}, socket) do
    case Enum.find(Games.all(), &(Atom.to_string(&1.id) == id)) do
      %{id: game_id} -> Room.pick_game(game_id)
      nil -> :ignore
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_updated, room}, socket), do: {:noreply, assign_room(socket, room)}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, redirect(socket, to: ~p"/table")}

  defp assign_room(socket, room) do
    assign(socket,
      room: room,
      main_class: if(is_nil(room.game_id), do: "tv shelf-room", else: "tv"),
      selected: if(is_nil(room.game_id), do: socket.assigns.selected),
      unbuilt: Enum.reject(Games.all(), & &1.playable?),
      spines: @spines
    )
  end

  # A game box grows when tapped, and goes back on the shelf as a spine while another is selected.
  defp box_state(_id, nil), do: nil
  defp box_state(id, id), do: "selected"
  defp box_state(_id, _selected), do: "shelved"

  defp joined(%{order: []}), do: "Nobody has joined yet."
  defp joined(room), do: "Joined so far: " <> Enum.map_join(room.order, ", ", &Room.name(room, &1))

  @impl true
  def render(assigns) do
    ~H"""
    <main class={@main_class}>
      <%= if is_nil(@room.game_id) do %>
        <header class="tv-head"><span class="wordmark">LAN Party</span></header>
        <div>
          <h1>Select the game</h1>
          <p class="joined">{joined(@room)}</p>
        </div>
        <section class="shelf" aria-label="Games">
          <div class="shelf-row">
            <a
              class={["box-uno", box_state(:uno, @selected)]}
              phx-click="select_game"
              phx-value-id="uno"
              aria-label="UNO, 2 to 8 players"
            >
              <span class="box-logo" aria-hidden="true">UNO</span>
              <span class="box-fan" aria-hidden="true">
                <.card card={%Card{id: 0, color: :red, value: 7}} style="--r:-16deg;--x:-42%" />
                <.card card={%Card{id: 0, color: :yellow, value: :reverse}} style="--r:0deg;--x:0%" />
                <.card card={%Card{id: 0, color: nil, value: :wild}} style="--r:16deg;--x:42%" />
              </span>
              <span class="box-tag">2 to 8 players</span>
              <span class="box-spine" aria-hidden="true"><b>UNO</b><small>2 to 8 players</small></span>
            </a>
            <a
              class={["box-dice", box_state(:liars_dice, @selected)]}
              phx-click="select_game"
              phx-value-id="liars_dice"
              aria-label="Liar's Dice, 2 to 8 players"
            >
              <span class="box-logo" aria-hidden="true">Liar's<br />Dice</span>
              <span class="box-art" aria-hidden="true">
                <Dice.face value={1} style="--x:-58%;--y:18%;--r:-14deg" />
                <Dice.face value={5} style="--x:62%;--y:24%;--r:11deg" />
                <Dice.face value={6} style="--x:0%;--y:-14%;--r:4deg" />
              </span>
              <span class="box-tag">2 to 8 players</span>
              <span class="box-spine" aria-hidden="true">
                <b>Liar's Dice</b><small>2 to 8 players</small>
              </span>
            </a>
            <div :for={game <- @unbuilt} class="spine" style={@spines[game.id]}>
              <b>{game.name}</b><small>Not built yet</small>
            </div>
            <div class="shelf-aside">
              <%= case @selected do %>
                <% :uno -> %>
                  <h2>UNO</h2>
                  <p>The classic card game.</p>
                  <button class="btn" phx-click="pick_game" phx-value-id="uno">Play UNO</button>
                <% :liars_dice -> %>
                  <h2>Liar's Dice</h2>
                  <p>Bluff about hidden dice.</p>
                  <button class="btn" phx-click="pick_game" phx-value-id="liars_dice">
                    Play Liar's Dice
                  </button>
                <% nil -> %>
                  <p>Tap a game to choose it.</p>
              <% end %>
            </div>
          </div>
          <div class="plank"></div>
        </section>
      <% end %>

      <.live_component
        :if={@room.game_id == :uno}
        module={LanPartyWeb.Uno.TableComponent}
        id="uno-table"
        room={@room}
      />

      <.live_component
        :if={@room.game_id == :liars_dice}
        module={LanPartyWeb.LiarsDice.TableComponent}
        id="liars-dice-table"
        room={@room}
      />
    </main>
    """
  end
end
