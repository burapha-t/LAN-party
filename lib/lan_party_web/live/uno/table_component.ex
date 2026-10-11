defmodule LanPartyWeb.Uno.TableComponent do
  @moduledoc """
  UNO on the table: the lobby (house rules, Start, Change game), the round (seats, pile, draw for
  player, Reset), and the result. Rendered by `TableLive` once UNO is picked.
  Markup follows mockups/table/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.Uno.Components

  alias LanParty.Room
  alias LanParty.Uno.View

  @rules [
    {:stack_plus2, "Stacking +2s", "Answer a +2 with a +2 and pass the total on."},
    {:stack_plus4, "Stacking +4s", "Answer a +4 with a +4 and pass the total on."},
    {:seven_zero, "7-0", "A 7 swaps hands with a player you pick. A 0 passes every hand along."},
    {:jump_in, "Jump-in", "Anyone can play an identical card out of turn. Play carries on from them."}
  ]

  @doc "Class for the table's <main>: the current color glows during and after a round."
  def main_class(%{phase: phase, game: %{color: color}})
      when phase in [:playing, :finished] and not is_nil(color),
      do: "tv glow-#{color}"

  def main_class(_room), do: "tv"

  @impl true
  def update(%{id: id, room: room}, socket) do
    view = if room.game, do: View.table_view(room.game)
    {top_row, bottom_row} = rows(view)

    {:ok,
     socket
     |> assign(id: id, room: room, view: view, rules: @rules, top_row: top_row, bottom_row: bottom_row)
     |> assign(seated: Room.seated(room), queued: Room.queued(room), leftovers: leftovers(view, room))
     |> assign_new(:draw_for, fn -> nil end)
     |> assign_new(:amount, fn -> 2 end)
     |> assign_new(:confirm_reset, fn -> false end)
     |> assign_new(:error, fn -> nil end)
     |> close_panels_outside_round()}
  end

  ## Events

  @impl true
  def handle_event("change_game", _params, socket), do: reply(socket, Room.change_game())
  def handle_event("start", _params, socket), do: reply(socket, Room.start_game())

  def handle_event("toggle", %{"rule" => rule}, socket) do
    case Enum.find(@rules, fn {key, _title, _help} -> Atom.to_string(key) == rule end) do
      {key, _title, _help} -> reply(socket, Room.update_settings(%{key => !socket.assigns.room.settings[key]}))
      nil -> {:noreply, socket}
    end
  end

  def handle_event("open_draw_for", %{"token" => token}, socket) do
    if socket.assigns.room.phase == :playing and Map.has_key?(socket.assigns.room.game.hands, token),
      do: {:noreply, assign(socket, draw_for: token, amount: 2)},
      else: {:noreply, socket}
  end

  def handle_event("amount", %{"delta" => delta}, socket) do
    change = if delta == "1", do: 1, else: -1
    {:noreply, assign(socket, amount: (socket.assigns.amount + change) |> max(1) |> min(10))}
  end

  def handle_event("confirm_draw_for", _params, socket) do
    result = Room.draw_for(socket.assigns.draw_for, socket.assigns.amount)
    reply(assign(socket, draw_for: nil), result)
  end

  def handle_event("ask_reset", _params, socket), do: {:noreply, assign(socket, confirm_reset: true)}
  def handle_event("cancel", _params, socket), do: {:noreply, assign(socket, draw_for: nil, confirm_reset: false)}

  def handle_event("back_to_lobby", _params, socket),
    do: reply(assign(socket, confirm_reset: false), Room.back_to_lobby())

  defp reply(socket, :ok), do: {:noreply, assign(socket, error: nil)}
  defp reply(socket, {:error, :not_enough_players}), do: {:noreply, assign(socket, error: "Start needs at least 2 players.")}
  defp reply(socket, {:error, _reason}), do: {:noreply, assign(socket, error: "That didn't work. Try again.")}

  ## What to show

  defp close_panels_outside_round(%{assigns: %{room: %{phase: :playing}}} = socket), do: socket
  defp close_panels_outside_round(socket), do: assign(socket, draw_for: nil, confirm_reset: false)

  # Seats around the table: the first half along the top, the rest along the bottom, right to left.
  defp rows(nil), do: {[], []}

  defp rows(%{counts: counts}) do
    {top, bottom} = Enum.split(counts, div(length(counts) + 1, 2))
    {top, Enum.reverse(bottom)}
  end

  defp leftovers(nil, _room), do: []
  defp leftovers(view, room), do: Enum.reject(view.counts, fn {token, _count} -> token == room.winner end)

  defp names(room, tokens), do: Enum.map(tokens, &Room.name(room, &1))

  defp join_note([one]), do: "#{one} joins at Play again."
  defp join_note(names), do: "#{Enum.join(Enum.drop(names, -1), ", ")} and #{List.last(names)} join at Play again."

  defp away?(room, token) do
    case room.people[token] do
      nil -> true
      person -> Room.away?(person)
    end
  end

  attr :token, :string, required: true
  attr :count, :integer, required: true
  attr :room, :map, required: true
  attr :current, :string, required: true
  attr :target, :any, required: true

  defp seat(assigns) do
    ~H"""
    <a
      class={["seat", @token == @current && "current", away?(@room, @token) && "away"]}
      phx-click="open_draw_for"
      phx-value-token={@token}
      phx-target={@target}
    >
      <span class="name">{Room.name(@room, @token)}</span>
      <span class="count">{@count}<small>{if @count == 1, do: "card", else: "cards"}</small></span>
      <span :if={away?(@room, @token)} class="tag">Away</span>
    </a>
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
            <span class="game-name">UNO</span>
            <button class="btn btn-secondary" phx-click="change_game" phx-target={@myself}>Change game</button>
          </header>
          <div class="lobby">
            <section>
              <h2>Players</h2>
              <ul class="people">
                <li :for={token <- @seated}>{Room.name(@room, token)}</li>
              </ul>
              <p :if={length(@seated) >= 2} class="lobby-note">{length(@seated)} of 8 seats taken.</p>
              <p :if={length(@seated) < 2} class="lobby-note"><span class="wait">Waiting for players to join</span></p>
              <p :if={@queued != []} class="lobby-note">Waiting for a seat: {Enum.join(names(@room, @queued), ", ")}</p>
            </section>
            <section>
              <h2>House rules</h2>
              <div class="rules">
                <label :for={{key, title, help} <- @rules} class="rule" for={"rule-#{key}"}>
                  <span><b>{title}</b><small>{help}</small></span>
                  <input
                    class="switch"
                    type="checkbox"
                    id={"rule-#{key}"}
                    checked={@room.settings[key]}
                    phx-click="toggle"
                    phx-value-rule={key}
                    phx-target={@myself}
                  />
                </label>
              </div>
            </section>
          </div>
          <div class="start-row">
            <button
              class="btn btn-primary btn-big"
              phx-click="start"
              phx-target={@myself}
              disabled={length(@seated) < 2}
            >
              Start game
            </button>
            <p :if={length(@seated) < 2}>Start needs at least 2 players.</p>
            <p :if={@error} role="alert">{@error}</p>
          </div>
        <% :playing -> %>
          <header class="tv-head">
            <span class="game-name">UNO</span>
            <button class="btn btn-secondary" phx-click="ask_reset" phx-target={@myself}>Reset</button>
          </header>
          <div class="ring">
            <div class="seats">
              <.seat
                :for={{token, count} <- @top_row}
                token={token}
                count={count}
                room={@room}
                current={@view.current}
                target={@myself}
              />
            </div>
            <div class="table-mid">
              <div class="draw-pile">
                <span class="card black stack" role="img" aria-label="Draw pile"><span class="face" aria-hidden="true"><span class="oval back-oval"></span><span class="logo">UNO</span></span></span>
                <span>{@view.draw_pile_size} cards</span>
              </div>
              <div class="top-card"><.card card={@view.top} /></div>
              <div class="table-info">
                <p class="turn">{Room.name(@room, @view.current)}'s turn</p>
                <p :if={@view.pending_total > 0} class="pending">
                  <b>+{@view.pending_total}</b> for {Room.name(@room, @view.current)}
                </p>
                <p class="facts">
                  <span>Color: {@view.color || "not picked yet"}</span>
                  <span>
                    <svg aria-hidden="true" style={@view.direction == -1 && "transform: scaleX(-1)"}>
                      <use href="#clockwise" />
                    </svg>{if @view.direction == 1, do: "Clockwise", else: "Counterclockwise"}
                  </span>
                </p>
              </div>
            </div>
            <div class="seats">
              <.seat
                :for={{token, count} <- @bottom_row}
                token={token}
                count={count}
                room={@room}
                current={@view.current}
                target={@myself}
              />
            </div>
          </div>
          <footer class="tv-foot">
            <span :if={@queued != []}>Next game: <strong>{Enum.join(names(@room, @queued), ", ")}</strong></span>
            <span :if={@queued == []}></span>
            <span>Tap a player to make them draw.</span>
          </footer>

          <div :if={@draw_for} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">Make {Room.name(@room, @draw_for)} draw</h2>
              <div class="stepper">
                <button type="button" aria-label="One fewer" phx-click="amount" phx-value-delta="-1" phx-target={@myself}>−</button>
                <output aria-live="polite">{@amount}</output>
                <button type="button" aria-label="One more" phx-click="amount" phx-value-delta="1" phx-target={@myself}>+</button>
              </div>
              <p>2 cards is the penalty for not saying UNO.</p>
              <div class="buttons">
                <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn btn-primary" phx-click="confirm_draw_for" phx-target={@myself}>Draw</button>
              </div>
            </div>
          </div>

          <div :if={@confirm_reset} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">End this round?</h2>
              <p>Nobody wins, and everyone goes back to the lobby.</p>
              <div class="buttons">
                <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn btn-primary" phx-click="back_to_lobby" phx-target={@myself}>End round</button>
              </div>
            </div>
          </div>
        <% :finished -> %>
          <header class="tv-head"><span class="game-name">UNO</span></header>
          <section class="winner">
            <.card card={@view.top} />
            <h1>{Room.name(@room, @room.winner) || "Someone"} won</h1>
            <p class="leftovers">
              <span>Cards left</span>
              <span :for={{token, count} <- @leftovers}>{Room.name(@room, token)} <b>{count}</b></span>
            </p>
            <div class="buttons">
              <button class="btn btn-primary btn-big" phx-click="back_to_lobby" phx-target={@myself}>Play again</button>
            </div>
            <p :if={@queued != []} class="lobby-note">{join_note(names(@room, @queued))}</p>
          </section>
      <% end %>
    </div>
    """
  end
end
