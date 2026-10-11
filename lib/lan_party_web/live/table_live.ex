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

    {:ok, assign_room(socket, Room.get_state())}
  end

  @impl true
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
      main_class:
        if(is_nil(room.game_id), do: "tv shelf-room", else: LanPartyWeb.Uno.TableComponent.main_class(room)),
      unbuilt: Enum.reject(Games.all(), & &1.playable?),
      spines: @spines
    )
  end

  defp joined(%{order: []}), do: "Nobody has joined yet."
  defp joined(room), do: "Joined so far: " <> Enum.map_join(room.order, ", ", &Room.name(room, &1))

  @impl true
  def render(assigns) do
    ~H"""
    <main class={@main_class}>
      <%= if is_nil(@room.game_id) do %>
        <header class="tv-head"><span class="brand">LAN Party</span></header>
        <div>
          <h1>Select the game</h1>
          <p class="joined">{joined(@room)}</p>
        </div>
        <section class="shelf" aria-label="Games">
          <div class="shelf-row">
            <a class="box-uno" phx-click="pick_game" phx-value-id="uno" aria-label="UNO, 2 to 8 players">
              <span class="box-logo" aria-hidden="true">UNO</span>
              <span class="box-fan" aria-hidden="true">
                <.card card={%Card{id: 0, color: :red, value: 7}} style="--r:-16deg;--x:-42%" />
                <.card card={%Card{id: 0, color: :yellow, value: :reverse}} style="--r:0deg;--x:0%" />
                <.card card={%Card{id: 0, color: nil, value: :wild}} style="--r:16deg;--x:42%" />
              </span>
              <span class="box-tag">2 to 8 players</span>
            </a>
            <div :for={game <- @unbuilt} class="spine" style={@spines[game.id]}>
              <b>{game.name}</b><small>Not built yet</small>
            </div>
            <div class="shelf-aside">
              <h2>UNO</h2>
              <p>The card game. Match the color or the number, and be the first to empty your hand.</p>
              <button class="btn btn-primary btn-big" phx-click="pick_game" phx-value-id="uno">Play UNO</button>
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
    </main>
    """
  end
end
