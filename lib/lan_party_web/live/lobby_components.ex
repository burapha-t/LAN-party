defmodule LanPartyWeb.LobbyComponents do
  @moduledoc """
  Lobby pieces every game shares (docs/liars-dice/design.md §3): a player's avatar, the table
  lobby's Players panel, and the phone's lobby and queue screens. The avatar and the panel follow
  docs/mockups/redesign/; the phone screens follow docs/mockups/platform/phone/ until those are redone.
  """
  use Phoenix.Component

  alias LanParty.Room

  @doc "A player's initial in their color. Colors go by arrival order for the night: `.p1` to `.p8`."
  attr :room, :map, required: true
  attr :token, :string, required: true

  def avatar(assigns) do
    ~H"""
    <span class={["avatar", color(@room, @token)]} aria-hidden="true">{initial(Room.name(@room, @token))}</span>
    """
  end

  defp color(room, token) do
    case Enum.find_index(room.order, &(&1 == token)) do
      nil -> nil
      index -> "p#{rem(index, 8) + 1}"
    end
  end

  defp initial(nil), do: ""
  defp initial(name), do: name |> String.first() |> String.upcase()

  @doc "The table lobby's Players panel: seated players in arrival order, then the free seats."
  attr :room, :map, required: true

  def players_panel(assigns) do
    assigns = assign(assigns, seated: Room.seated(assigns.room), queued: Room.queued(assigns.room))

    ~H"""
    <section class="panel">
      <div class="panel-head">
        <h2>Players</h2>
        <span class="seats-left">{length(@seated)} of 8 seats taken</span>
      </div>
      <ul class="roster">
        <li :for={token <- @seated}><.avatar room={@room} token={token} /><span>{Room.name(@room, token)}</span></li>
        <li :for={_seat <- 1..(8 - length(@seated))//1} class="open">
          <span class="avatar" aria-hidden="true"></span><span>Free seat</span>
        </li>
      </ul>
      <p :if={length(@seated) < 2} class="wait">Waiting for players to join</p>
      <p :if={@queued != []} class="lobby-note">
        Waiting for a seat: {Enum.map_join(@queued, ", ", &Room.name(@room, &1))}
      </p>
    </section>
    """
  end

  @doc "The phone in a game's lobby: who is seated, waiting for the table to start."
  attr :room, :map, required: true
  attr :token, :string, required: true

  def phone_lobby(assigns) do
    ~H"""
    <div class="message">
      <h1>You're in.</h1>
      <a class="wait">Waiting for the table to start</a>
      <div>
        <p class="people-label">Players</p>
        <ul class="people">
          <li :for={token <- Room.seated(@room)} class={token == @token && "you"}>
            {Room.name(@room, token)}{if token == @token, do: " (you)"}
          </li>
        </ul>
      </div>
    </div>
    """
  end

  @doc "The phone in the queue: its place in line, and what it waits for."
  attr :room, :map, required: true
  attr :token, :string, required: true

  def phone_queue(assigns) do
    assigns = assign(assigns, :place, Enum.find_index(Room.queued(assigns.room), &(&1 == assigns.token)) + 1)

    ~H"""
    <div class="message">
      <h1>{"You're ##{@place} in line."}</h1>
      <p :if={@room.phase != :lobby} class="lead">A game is in progress. You'll play in the next one.</p>
      <a :if={@room.phase != :lobby} class="wait">Waiting for this round to end</a>
      <p :if={@room.phase == :lobby} class="lead">The table is full. You'll play in the next one.</p>
      <a :if={@room.phase == :lobby} class="wait">Waiting for a free seat</a>
    </div>
    """
  end
end
