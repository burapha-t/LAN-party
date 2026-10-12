defmodule LanPartyWeb.LiarsDice.PlayerComponent do
  @moduledoc """
  Liar's Dice on a phone: lobby, queue, your dice (the roll animation and the count highlight), out,
  and the result. No buttons: the phone is a dice cup. Rendered by `PlayerLive` once the table picks
  Liar's Dice. Shows only this player's dice (docs/liars-dice/README.md "Views").
  Markup follows docs/mockups/redesign/liars-dice/phone/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.LiarsDice.Components
  import LanPartyWeb.LobbyComponents

  alias LanParty.Room
  alias LanParty.LiarsDice.View

  @impl true
  def update(%{id: id, room: room, token: token}, socket) do
    in_game? = not is_nil(room.game) and token in room.game.players
    view = if in_game?, do: View.player_view(room.game, token)

    {:ok,
     socket
     |> assign(id: id, room: room, token: token, view: view)
     |> assign(screen: screen(room, room.people[token], view))
     |> assign_seen_roll(room, view)}
  end

  ## What to show

  defp screen(_room, %{status: :queued}, _view), do: :queue
  defp screen(%{phase: :playing}, _me, %{out?: true}), do: :out
  defp screen(%{phase: :playing}, _me, %{}), do: :dice
  defp screen(%{phase: :finished}, _me, %{}), do: :finished
  defp screen(_room, _me, _view), do: :lobby

  # The roll animation plays only for rolls that happen while this page is open (design.md §5): remember
  # the roll this page first saw and animate only later ones. Outside a game it resets, so the first roll
  # of the next game animates.
  defp assign_seen_roll(socket, %{phase: :playing}, %{roll: roll}),
    do: assign_new(socket, :seen_roll, fn -> roll end)

  defp assign_seen_roll(socket, _room, _view), do: assign(socket, seen_roll: 0)

  # During a count, the dice showing the face, or a wild 1, light up; the rest dim.
  defp count_state(_value, nil), do: nil
  defp count_state(value, face) when value == face or value == 1, do: "lit"
  defp count_state(_value, _face), do: "dim"

  ## Render

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} style="display: contents">
      <.phone_lobby :if={@screen == :lobby} room={@room} token={@token} />
      <.phone_queue :if={@screen == :queue} room={@room} token={@token} />

      <%= if @screen == :dice do %>
        <section class="stage" aria-label="Your dice">
          <p :if={@view.face} class="counting">Counting <b>{@view.face}s</b></p>
          <p :if={@view.face} class="stage-hint">1s are wild. Show your phone.</p>
          <div class="dice">
            <.die
              :for={{value, index} <- Enum.with_index(@view.dice)}
              id={"die-#{@view.roll}-#{index}"}
              value={value}
              rolling={@view.roll > @seen_roll}
              state={count_state(value, @view.face)}
            />
          </div>
        </section>
        <p :if={is_nil(@view.face)} class="hint dice-hint">
          Bids are out loud. Keep your dice hidden.
        </p>
      <% end %>

      <div :if={@screen == :out} class="message">
        <h1>You're out.</h1>
        <p class="lead">No dice left. Watch the rest of the game on the table.</p>
        <a class="wait">Waiting for the game to end</a>
      </div>

      <div :if={@screen == :finished and @room.winner == @token} class="message centered">
        <div class="dice"><.die :for={value <- @view.dice} value={value} /></div>
        <h1 class="huge win">You won!</h1>
        <a class="wait">Waiting for the table</a>
      </div>

      <div :if={@screen == :finished and @room.winner != @token} class="message centered">
        <.avatar :if={@room.people[@room.winner]} room={@room} token={@room.winner} />
        <h1 class="huge">{Room.name(@room, @room.winner) || "Someone"} won</h1>
        <p class="lead">Last one with dice</p>
        <a class="wait">Waiting for the table</a>
      </div>
    </div>
    """
  end
end
