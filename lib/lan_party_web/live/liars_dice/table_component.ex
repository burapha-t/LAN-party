defmodule LanPartyWeb.LiarsDice.TableComponent do
  @moduledoc """
  Liar's Dice on the table: the lobby (Start, Change game), the game (seats with dice counts, the
  total, the face picker, Roll, take a die, Reset), and the winner. Rendered by `TableLive` once
  Liar's Dice is picked. Never shows a die's value (docs/liars-dice/README.md "Views").
  Markup follows docs/mockups/redesign/liars-dice/table/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.LiarsDice.Components
  import LanPartyWeb.LobbyComponents

  alias LanParty.Room
  alias LanParty.LiarsDice.View

  @impl true
  def update(%{id: id, room: room}, socket) do
    view = if room.game, do: View.table_view(room.game)
    {top_row, bottom_row} = rows(view)

    {:ok,
     socket
     |> assign(id: id, room: room, view: view, top_row: top_row, bottom_row: bottom_row)
     |> assign(seated: Room.seated(room), queued: Room.queued(room))
     |> assign_new(:take, fn -> nil end)
     |> assign_new(:confirm_reset, fn -> false end)
     |> assign_new(:error, fn -> nil end)
     |> close_stale_panels()}
  end

  ## Events

  @impl true
  def handle_event("change_game", _params, socket), do: reply(socket, Room.change_game())
  def handle_event("start", _params, socket), do: reply(socket, Room.start_game())
  def handle_event("roll", _params, socket), do: reply(socket, Room.table_act(:roll))

  def handle_event("count", %{"face" => face}, socket) do
    case Integer.parse(face) do
      {face, ""} when face in 2..6 -> reply(socket, Room.table_act({:count, face}))
      _junk -> {:noreply, socket}
    end
  end

  def handle_event("open_take", %{"token" => token}, socket) do
    if socket.assigns.room.phase == :playing and dice_count(socket.assigns.view, token) > 0,
      do: {:noreply, assign(socket, take: token)},
      else: {:noreply, socket}
  end

  # A second tap on Remove arrives after the panel closed: ignore it.
  def handle_event("take", _params, %{assigns: %{take: nil}} = socket), do: {:noreply, socket}

  def handle_event("take", _params, socket) do
    result = Room.table_act({:take_die, socket.assigns.take})
    reply(assign(socket, take: nil), result)
  end

  def handle_event("ask_reset", _params, socket),
    do: {:noreply, assign(socket, confirm_reset: true)}

  def handle_event("cancel", _params, socket),
    do: {:noreply, assign(socket, take: nil, confirm_reset: false)}

  def handle_event("back_to_lobby", _params, socket),
    do: reply(assign(socket, confirm_reset: false), Room.back_to_lobby())

  defp reply(socket, :ok), do: {:noreply, assign(socket, error: nil)}

  defp reply(socket, {:error, :not_enough_players}),
    do: {:noreply, assign(socket, error: "Start needs at least 2 players.")}

  defp reply(socket, {:error, _reason}),
    do: {:noreply, assign(socket, error: "That didn't work. Try again.")}

  ## What to show

  # Panels close outside a game. The take-a-die panel also closes when its player has no dice left
  # (another table took the last one) or has left the game.
  defp close_stale_panels(
         %{assigns: %{room: %{phase: :playing}, take: take, view: view}} = socket
       ) do
    if take && dice_count(view, take) == 0, do: assign(socket, take: nil), else: socket
  end

  defp close_stale_panels(socket), do: assign(socket, take: nil, confirm_reset: false)

  defp dice_count(view, token),
    do: Enum.find_value(view.counts, 0, fn {t, count} -> t == token && count end)

  # Seats around the table: the first half along the top, the rest along the bottom, right to left.
  defp rows(nil), do: {[], []}

  defp rows(%{counts: counts}) do
    {top, bottom} = Enum.split(counts, div(length(counts) + 1, 2))
    {top, Enum.reverse(bottom)}
  end

  defp take_text(room, view, token) do
    name = Room.name(room, token)
    count = dice_count(view, token)
    others = for {other, n} <- view.counts, other != token, n > 0, do: other

    cond do
      count > 1 ->
        %{
          title: "Take a die from #{name}?",
          line: "#{name} goes from #{count} dice to #{count - 1}."
        }

      match?([_], others) ->
        %{
          title: "Take #{name}'s last die?",
          line: "#{name} is out, and #{Room.name(room, hd(others))} wins."
        }

      true ->
        %{title: "Take #{name}'s last die?", line: "#{name} is out of the game."}
    end
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
  attr :count, :integer, required: true
  attr :room, :map, required: true
  attr :target, :any, required: true

  # Out of the game: the seat lies flat and can't be tapped.
  defp seat(%{count: 0} = assigns) do
    ~H"""
    <div class="seat out">
      <.avatar room={@room} token={@token} />
      <span class="who">
        <span class="name">{Room.name(@room, @token)}</span>
        <span class="pill"><span class="dot coral"></span>Out</span>
      </span>
      <span class="count">0<small>dice</small></span>
    </div>
    """
  end

  defp seat(assigns) do
    ~H"""
    <a
      class={["seat", away?(@room, @token) && "away"]}
      phx-click="open_take"
      phx-value-token={@token}
      phx-target={@target}
    >
      <.avatar room={@room} token={@token} />
      <span class="who">
        <span class="name">{Room.name(@room, @token)}</span>
        <span :if={away?(@room, @token)} class="pill"><span class="dot sun"></span>Away</span>
      </span>
      <span class="count">{@count}<small>{if @count == 1, do: "die", else: "dice"}</small></span>
    </a>
    """
  end

  ## Render

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        take_text: assigns.take && take_text(assigns.room, assigns.view, assigns.take)
      )

    ~H"""
    <div id={@id} style="display: contents">
      <%= case @room.phase do %>
        <% :lobby -> %>
          <header class="tv-head">
            <span class="wordmark">Liar's Dice</span>
            <button class="btn btn-quiet" phx-click="change_game" phx-target={@myself}>
              Change game
            </button>
          </header>
          <div class="lobby solo">
            <.players_panel room={@room} />
          </div>
          <div class="start-row">
            <p :if={length(@seated) < 2}>Start needs at least 2 players.</p>
            <p :if={length(@seated) >= 2}>Everyone starts with 5 dice.</p>
            <p :if={@error} role="alert">{@error}</p>
            <button
              class="btn btn-big"
              phx-click="start"
              phx-target={@myself}
              disabled={length(@seated) < 2}
            >
              Start game
            </button>
          </div>
        <% :playing -> %>
          <header class="tv-head">
            <span class="wordmark">Liar's Dice</span>
            <button class="btn btn-quiet" phx-click="ask_reset" phx-target={@myself}>Reset</button>
          </header>
          <div class="ring">
            <div class={["seats", length(@top_row) > 3 && "four"]}>
              <.seat
                :for={{token, count} <- @top_row}
                token={token}
                count={count}
                room={@room}
                target={@myself}
              />
            </div>
            <div class="felt felt-dice">
              <p class="dice-total"><b>{@view.total}</b><span>dice in play</span></p>
              <div class="face-pick" role="group" aria-label="Light up a face on every phone">
                <p :if={is_nil(@view.face)}>Someone called "Liar!"? Pick the face that was bid.</p>
                <p :if={@view.face}>
                  Counting <b>{@view.face}s</b>. 1s are wild. Count the phones out loud.
                </p>
                <div class="face-row">
                  <a
                    :for={face <- 2..6}
                    class="face-btn"
                    role="button"
                    aria-label={"Count #{face}s"}
                    aria-pressed={to_string(@view.face == face)}
                    phx-click="count"
                    phx-value-face={face}
                    phx-target={@myself}
                  >
                    <.face value={face} />
                  </a>
                </div>
              </div>
              <button class="btn btn-big roll" phx-click="roll" phx-target={@myself}>Roll</button>
            </div>
            <div class={["seats", length(@bottom_row) > 3 && "four"]}>
              <.seat
                :for={{token, count} <- @bottom_row}
                token={token}
                count={count}
                room={@room}
                target={@myself}
              />
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
            <span :if={!@error}>Tap a player to take a die.</span>
          </footer>

          <div :if={@take_text} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">{@take_text.title}</h2>
              <p>{@take_text.line}</p>
              <div class="buttons">
                <button class="btn btn-quiet" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn" phx-click="take" phx-target={@myself}>Remove</button>
              </div>
            </div>
          </div>

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
          <header class="tv-head"><span class="wordmark">Liar's Dice</span></header>
          <section class="winner">
            <.avatar :if={@room.people[@room.winner]} room={@room} token={@room.winner} />
            <h1>{Room.name(@room, @room.winner) || "Someone"} won</h1>
            <p class="lead">Last one with dice</p>
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
