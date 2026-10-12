defmodule LanPartyWeb.Undercover.TableComponent do
  @moduledoc """
  Undercover on the table: the lobby (Start, Change game), the game (seats, the undercover count,
  Reroll, Reset), and the winner. Rendered by `TableLive` once Undercover is picked. Never shows a
  word or a role (docs/undercover/README.md "Views"). Laid out like Liar's Dice's table.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.LobbyComponents

  alias LanParty.{Games, Room}
  alias LanParty.Undercover.View

  @min_players Games.min_players(:undercover)

  @impl true
  def update(%{id: id, room: room}, socket) do
    view = if room.game, do: View.table_view(room.game)
    {top_row, bottom_row} = rows(view)

    {:ok,
     socket
     |> assign(id: id, room: room, view: view, top_row: top_row, bottom_row: bottom_row)
     |> assign(seated: Room.seated(room), queued: Room.queued(room), min_players: @min_players)
     |> assign_new(:confirm_reset, fn -> false end)
     |> assign_new(:error, fn -> nil end)
     |> close_stale_panels()}
  end

  ## Events

  @impl true
  def handle_event("change_game", _params, socket), do: reply(socket, Room.change_game())
  def handle_event("start", _params, socket), do: reply(socket, Room.start_game())
  def handle_event("reroll", _params, socket), do: reply(socket, Room.table_act(:reroll))

  def handle_event("ask_reset", _params, socket),
    do: {:noreply, assign(socket, confirm_reset: true)}

  def handle_event("cancel", _params, socket),
    do: {:noreply, assign(socket, confirm_reset: false)}

  def handle_event("back_to_lobby", _params, socket),
    do: reply(assign(socket, confirm_reset: false), Room.back_to_lobby())

  defp reply(socket, :ok), do: {:noreply, assign(socket, error: nil)}

  defp reply(socket, {:error, :not_enough_players}),
    do: {:noreply, assign(socket, error: "Start needs at least #{@min_players} players.")}

  defp reply(socket, {:error, _reason}),
    do: {:noreply, assign(socket, error: "That didn't work. Try again.")}

  ## What to show

  # The Reset panel closes outside a game.
  defp close_stale_panels(%{assigns: %{room: %{phase: :playing}}} = socket), do: socket
  defp close_stale_panels(socket), do: assign(socket, confirm_reset: false)

  # Seats around the table: the first half along the top, the rest along the bottom, right to left.
  defp rows(nil), do: {[], []}

  defp rows(%{players: players}) do
    {top, bottom} = Enum.split(players, div(length(players) + 1, 2))
    {top, Enum.reverse(bottom)}
  end

  defp names(room, tokens), do: Enum.map(tokens, &Room.name(room, &1))

  defp join_note([one]), do: "#{one} joins at Play again."

  defp join_note(names),
    do: "#{Enum.join(Enum.drop(names, -1), ", ")} and #{List.last(names)} join at Play again."

  defp away?(room, token) do
    case room.people[token] do
      nil -> true
      person -> Room.away?(person)
    end
  end

  attr :token, :string, required: true
  attr :room, :map, required: true

  # Just a name: no counts, and nothing to tap.
  defp seat(assigns) do
    ~H"""
    <div class={["seat", "plain", away?(@room, @token) && "away"]}>
      <.avatar room={@room} token={@token} />
      <span class="who">
        <span class="name">{Room.name(@room, @token)}</span>
        <span :if={away?(@room, @token)} class="pill"><span class="dot sun"></span>Away</span>
      </span>
    </div>
    """
  end

  ## Render

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} style="display: contents">
      <%= case @room.phase do %>
        <% :lobby -> %>
          <header class="tv-head">
            <span class="wordmark">Undercover</span>
            <button class="btn btn-quiet" phx-click="change_game" phx-target={@myself}>
              Change game
            </button>
          </header>
          <div class="lobby solo">
            <.players_panel room={@room} />
          </div>
          <div class="start-row">
            <p :if={length(@seated) < @min_players}>Start needs at least {@min_players} players.</p>
            <p :if={@error} role="alert">{@error}</p>
            <button
              class="btn btn-big"
              phx-click="start"
              phx-target={@myself}
              disabled={length(@seated) < @min_players}
            >
              Start game
            </button>
          </div>
        <% :playing -> %>
          <header class="tv-head">
            <span class="wordmark">Undercover</span>
            <button class="btn btn-quiet" phx-click="ask_reset" phx-target={@myself}>Reset</button>
          </header>
          <div class="ring">
            <div class={["seats", length(@top_row) > 3 && "four"]}>
              <.seat :for={token <- @top_row} token={token} room={@room} />
            </div>
            <div class="felt felt-undercover">
              <p class="undercover-total">
                <b>{@view.undercovers}</b><span>{if @view.undercovers == 1, do: "undercover", else: "undercovers"}</span>
              </p>
              <p class="felt-note">Describe your word without saying it. Then vote someone out.</p>
              <button class="btn btn-big roll" phx-click="reroll" phx-target={@myself}>Reroll</button>
            </div>
            <div class={["seats", length(@bottom_row) > 3 && "four"]}>
              <.seat :for={token <- @bottom_row} token={token} room={@room} />
            </div>
          </div>
          <footer class="tv-foot">
            <span :if={@queued != []} class="next">
              Next game:
              <span class="faces" aria-hidden="true">
                <.avatar :for={token <- @queued} room={@room} token={token} />
              </span>
              <strong>{Enum.join(names(@room, @queued), ", ")}</strong>
            </span>
            <span :if={@queued == []}></span>
            <span :if={@error} role="alert">{@error}</span>
            <span :if={!@error}>Voted out? Show your phone.</span>
          </footer>

          <div :if={@confirm_reset} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">End this game?</h2>
              <p>Nobody wins, and everyone goes back to the lobby.</p>
              <div class="buttons">
                <button class="btn btn-quiet" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn" phx-click="back_to_lobby" phx-target={@myself}>End game</button>
              </div>
            </div>
          </div>
        <% :finished -> %>
          <header class="tv-head"><span class="wordmark">Undercover</span></header>
          <section class="winner">
            <.avatar :if={@room.people[@room.winner]} room={@room} token={@room.winner} />
            <h1>{Room.name(@room, @room.winner) || "Someone"} won</h1>
            <p class="lead">Last one left</p>
            <div class="buttons">
              <button class="btn btn-big" phx-click="back_to_lobby" phx-target={@myself}>
                Play again
              </button>
            </div>
            <p :if={@queued != []} class="lobby-note">{join_note(names(@room, @queued))}</p>
          </section>
      <% end %>
    </div>
    """
  end
end
