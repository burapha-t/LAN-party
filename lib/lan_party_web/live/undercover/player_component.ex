defmodule LanPartyWeb.Undercover.PlayerComponent do
  @moduledoc """
  Undercover on a phone: lobby, queue, your word on a paper slip, and the result. No buttons: the
  phone is a slip of paper. Rendered by `PlayerLive` once the table picks Undercover. Shows only this
  player's word, and never what they are (docs/undercover/README.md "Views").
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.Undercover.Components
  import LanPartyWeb.LobbyComponents

  alias LanParty.Room
  alias LanParty.Undercover.View

  @impl true
  def update(%{id: id, room: room, token: token}, socket) do
    in_game? = not is_nil(room.game) and token in room.game.players
    view = if in_game?, do: View.player_view(room.game, token)

    {:ok,
     socket
     |> assign(id: id, room: room, token: token, view: view)
     |> assign(screen: screen(room, room.people[token], view))
     |> assign_seen_deal(room, view)}
  end

  ## What to show

  defp screen(_room, %{status: :queued}, _view), do: :queue
  defp screen(%{phase: :playing}, _me, %{}), do: :word
  defp screen(%{phase: :finished}, _me, %{}), do: :finished
  defp screen(_room, _me, _view), do: :lobby

  # The slip slides in only for deals that happen while this page is open: remember the deal this page
  # first saw and animate only later ones. Outside a game it resets, so the first deal of the next
  # game animates.
  defp assign_seen_deal(socket, %{phase: :playing}, %{deal: deal}),
    do: assign_new(socket, :seen_deal, fn -> deal end)

  defp assign_seen_deal(socket, _room, _view), do: assign(socket, seen_deal: 0)

  defp hint(1), do: "1 player has a different word. It could be you."
  defp hint(count), do: "#{count} players have a different word. It could be you."

  ## Render

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} style="display: contents">
      <.phone_lobby :if={@screen == :lobby} room={@room} token={@token} />
      <.phone_queue :if={@screen == :queue} room={@room} token={@token} />

      <section :if={@screen == :word} class="stage" aria-label="Your word">
        <.slip id={"slip-#{@view.deal}"} word={@view.word} dealt={@view.deal > @seen_deal} />
        <p class="stage-hint">{hint(@view.undercovers)}</p>
      </section>

      <div :if={@screen == :finished and @room.winner == @token} class="message centered">
        <h1 class="huge win">You won!</h1>
        <a class="wait">Waiting for the table</a>
      </div>

      <div :if={@screen == :finished and @room.winner != @token} class="message centered">
        <.avatar :if={@room.people[@room.winner]} room={@room} token={@room.winner} />
        <h1 class="huge">{Room.name(@room, @room.winner) || "Someone"} won</h1>
        <p class="lead">Last one left</p>
        <a class="wait">Waiting for the table</a>
      </div>
    </div>
    """
  end
end
