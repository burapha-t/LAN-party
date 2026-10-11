defmodule LanPartyWeb.Uno.PlayerComponent do
  @moduledoc """
  UNO on a phone: lobby, queue, the round, prompts, and the result. Rendered by `PlayerLive` once the
  table picks UNO. Never shows the pile or the current color (docs/uno/README.md "Views").
  Markup follows docs/mockups/phone/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.Uno.Components

  alias LanParty.Room
  alias LanParty.Uno.{Card, View}

  @colors %{"red" => :red, "yellow" => :yellow, "green" => :green, "blue" => :blue}

  @doc "Class for the phone's <main>: brighter when you must act; the winning color at the end."
  def glow(%{phase: :playing, game: game}, token) do
    if game.current == token and not match?({:start_color, _}, game.pending), do: "glow-turn"
  end

  def glow(%{phase: :finished, game: %{color: color}}, _token) when not is_nil(color), do: "glow-#{color}"
  def glow(_room, _token), do: nil

  @impl true
  def update(%{id: id, room: room, token: token}, socket) do
    in_round? = not is_nil(room.game) and Map.has_key?(room.game.hands, token)
    view = if in_round?, do: View.player_view(room.game, token)

    {:ok,
     socket
     |> assign(id: id, room: room, token: token, view: view)
     |> assign(screen: screen(room, room.people[token], in_round?), stage: stage(view, room), hint: hint(view))
     |> assign_new(:sheet, fn -> nil end)
     |> then(fn socket -> if room.phase == :playing, do: socket, else: assign(socket, sheet: nil) end)
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:dismissed, fn -> nil end)}
  end

  ## Events

  @impl true
  def handle_event("play", %{"id" => id}, socket) do
    with {card_id, ""} <- Integer.parse(id),
         %{hand: hand} = view <- socket.assigns.view,
         %Card{} = card <- Enum.find(hand, &(&1.id == card_id)) do
      cond do
        Card.wild?(card) -> {:noreply, assign(socket, sheet: {:color, card_id}, error: nil)}
        card.value == 7 and view.seven_zero? -> {:noreply, assign(socket, sheet: {:swap, card_id}, error: nil)}
        true -> act(socket, {:play, card_id, %{}})
      end
    else
      _no_such_card -> {:noreply, socket}
    end
  end

  def handle_event("pick_color", %{"color" => color}, socket) do
    case {socket.assigns.sheet, Map.fetch(@colors, color)} do
      {{:color, card_id}, {:ok, color}} -> act(socket, {:play, card_id, %{color: color}})
      _other -> {:noreply, socket}
    end
  end

  def handle_event("pick_player", %{"token" => target}, socket) do
    case socket.assigns.sheet do
      {:swap, card_id} -> act(socket, {:play, card_id, %{swap_with: target}})
      _other -> {:noreply, socket}
    end
  end

  def handle_event("start_color", %{"color" => color}, socket) do
    case Map.fetch(@colors, color) do
      {:ok, color} -> act(socket, {:choose_color, color})
      :error -> {:noreply, socket}
    end
  end

  def handle_event("cancel", _params, socket), do: {:noreply, assign(socket, sheet: nil)}

  def handle_event("dismiss", _params, socket) do
    dismissed = socket.assigns.view && socket.assigns.view.last_challenge
    {:noreply, assign(socket, error: nil, dismissed: dismissed)}
  end

  def handle_event(action, _params, socket) when action in ~w(draw keep accept challenge),
    do: act(socket, String.to_existing_atom(action))

  defp act(socket, action) do
    case Room.act(socket.assigns.token, action) do
      :ok -> {:noreply, assign(socket, error: nil, sheet: nil)}
      {:error, reason} -> {:noreply, assign(socket, error: message(reason, socket.assigns.view), sheet: nil)}
    end
  end

  ## What to show

  defp screen(_room, %{status: :queued}, _in_round?), do: :queue
  defp screen(%{phase: :playing}, _me, true), do: :playing
  defp screen(%{phase: :finished}, _me, _in_round?), do: :finished
  defp screen(_room, _me, _in_round?), do: :lobby

  defp stage(nil, _room), do: nil

  defp stage(view, room) do
    case view.prompt do
      {:penalty, total, _can_challenge?} -> {:penalty, total, view.last_played_by && Room.name(room, view.last_played_by)}
      :choose_start_color -> :start_color
      _other -> if view.my_turn?, do: :my_turn, else: {:turn, Room.name(room, view.current)}
    end
  end

  defp hint(%{prompt: {:penalty, _total, _challenge?}, stack_options: [_ | _] = options}),
    do: "Or tap a #{stack_label(options)} in your hand to stack it."

  defp hint(_view), do: nil

  defp stack_label([:draw2]), do: "+2"
  defp stack_label([:wild_draw4]), do: "+4"
  defp stack_label(_both), do: "+2 or +4"

  # The bottom sheet, if any: a local picker first, then what the game is asking for.
  defp sheet({:color, _card_id}, %{prompt: {:penalty, total, _}, next: next}, room),
    do: {:color, "Pick a color for your +4", "#{Room.name(room, next)} faces +#{total + 4}."}

  defp sheet({:color, _card_id}, _view, _room), do: {:color, "Pick a color", nil}
  defp sheet({:swap, _card_id}, _view, _room), do: :swap
  defp sheet(nil, %{prompt: :choose_start_color}, _room), do: :start_color
  defp sheet(nil, %{prompt: {:drawn, card}}, _room), do: {:drawn, card}
  defp sheet(_sheet, _view, _room), do: nil

  defp message(:not_your_turn, _view), do: "Not your turn"
  defp message(:does_not_match, view), do: "Doesn't match: #{top_label(view)}"
  defp message(:resolve_penalty, view), do: penalty_message(view)
  defp message(:choose_start_color, _view), do: "Pick the starting color first"
  defp message(:play_drawn_or_keep, _view), do: "Play the card you drew, or keep it"
  defp message(_reason, _view), do: "You can't do that right now"

  defp top_label(%{top: top, color: color}) do
    if Card.wild?(top), do: "#{Card.label(top)} (#{color})", else: Card.label(top)
  end

  defp penalty_message(%{prompt: {:penalty, total, can_challenge?}, stack_options: options}) do
    choices =
      ["Draw #{total}"] ++
        if(can_challenge?, do: ["challenge"], else: []) ++
        if(options != [], do: ["stack a #{stack_label(options)}"], else: [])

    or_join(choices) <> " first"
  end

  defp penalty_message(_view), do: "Take the penalty first"

  defp or_join([one]), do: one
  defp or_join([first, second]), do: "#{first} or #{second}"
  defp or_join(choices), do: Enum.join(Enum.drop(choices, -1), ", ") <> ", or " <> List.last(choices)

  # After a challenge, both people involved get a message until they tap OK or someone acts.
  defp challenge_note(%{last_challenge: %{} = result}, room, token, dismissed) when result != dismissed do
    by = Room.name(room, result.by)
    challenger = Room.name(room, result.challenger)

    cond do
      token == result.challenger and result.legal -> "#{by} had no #{result.color} card, so the +4 was fair. You drew 6."
      token == result.challenger -> "#{by} had a #{result.color} card, so #{by} drew 4."
      token == result.by and result.legal -> "#{challenger} challenged your +4 and drew 6."
      token == result.by -> "#{challenger} caught your bluff. You had a #{result.color} card, so you drew 4."
      true -> nil
    end
  end

  defp challenge_note(_view, _room, _token, _dismissed), do: nil

  defp queue_number(room, token), do: Enum.find_index(Room.queued(room), &(&1 == token)) + 1

  defp cards(1), do: "1 card"
  defp cards(n), do: "#{n} cards"

  defp winner_line(%{winner: token}, token), do: "You won!"
  defp winner_line(room, _token), do: "#{Room.name(room, room.winner) || "Someone"} won"

  ## Render

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        current_sheet: sheet(assigns.sheet, assigns.view, assigns.room),
        note: challenge_note(assigns.view, assigns.room, assigns.token, assigns.dismissed)
      )

    ~H"""
    <div id={@id} style="display: contents">
      <div :if={@screen == :lobby} class="message">
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

      <div :if={@screen == :queue} class="message">
        <h1>{"You're ##{queue_number(@room, @token)} in line."}</h1>
        <p :if={@room.phase != :lobby} class="lead">A game is in progress. You'll play in the next one.</p>
        <a :if={@room.phase != :lobby} class="wait">Waiting for this round to end</a>
        <p :if={@room.phase == :lobby} class="lead">The table is full. You'll play in the next one.</p>
        <a :if={@room.phase == :lobby} class="wait">Waiting for a free seat</a>
      </div>

      <div :if={@screen == :finished} class="message centered">
        <.card card={LanParty.Uno.Rules.top_card(@room.game)} />
        <h1 class="huge">{winner_line(@room, @token)}</h1>
        <p :if={@room.winner != @token} class="lead">
          Last card: {Card.label(LanParty.Uno.Rules.top_card(@room.game))}
        </p>
        <a class="wait">Waiting for the table</a>
      </div>

      <%= if @screen == :playing do %>
        <div class="stage">
          <%= case @stage do %>
            <% {:penalty, total, by} -> %>
              <p class="threat"><b>+{total}</b>coming at you</p>
              <p :if={by} class="threat-sub">{by} played it.</p>
            <% :start_color -> %>
              <p class="turn">You go first</p>
            <% :my_turn -> %>
              <p class="your-turn">Your turn</p>
              <p class="stage-hint">Match the top card on the table.</p>
            <% {:turn, name} -> %>
              <a class="turn">{name}'s turn</a>
          <% end %>
        </div>

        <p :if={@hint} class="hint">{@hint}</p>
        <.toast :if={@error} message={@error} phx-click="dismiss" phx-target={@myself} />
        <.toast :if={@note && !@error} message={@note} phx-click="dismiss" phx-target={@myself} />

        <section aria-label="Your hand">
          <div class={["hand", length(@view.hand) == 1 && "one"]}>
            <.card_button
              :for={card <- @view.hand}
              card={card}
              phx-click="play"
              phx-value-id={card.id}
              phx-target={@myself}
            />
          </div>
        </section>

        <div class="actions">
          <%= case @view.prompt do %>
            <% {:penalty, total, can_challenge?} -> %>
              <button class="btn btn-primary" phx-click="accept" phx-target={@myself}>Draw {total}</button>
              <button :if={can_challenge?} class="btn btn-secondary" phx-click="challenge" phx-target={@myself}>
                Challenge
              </button>
            <% _other -> %>
              <button class="btn btn-secondary" phx-click="draw" phx-target={@myself}>Draw</button>
          <% end %>
        </div>

        <%= case @current_sheet do %>
          <% {:color, title, sub} -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">{title}</h2>
              <p :if={sub} class="sub">{sub}</p>
              <div class="swatches">
                <a
                  :for={color <- ~w(red yellow green blue)}
                  class={["swatch", color]}
                  phx-click="pick_color"
                  phx-value-color={color}
                  phx-target={@myself}
                >
                  {String.capitalize(color)}
                </a>
              </div>
              <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
            </section>
          <% :swap -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">Swap hands with…</h2>
              <p class="sub">You played a 7. They get your hand, you get theirs.</p>
              <div class="pick-list">
                <a :for={token <- @view.others} phx-click="pick_player" phx-value-token={token} phx-target={@myself}>
                  {Room.name(@room, token)}<span>{cards(@view.counts[token])}</span>
                </a>
              </div>
              <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
            </section>
          <% :start_color -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">Pick the starting color</h2>
              <p class="sub">The first card is a Wild.</p>
              <div class="swatches">
                <a
                  :for={color <- ~w(red yellow green blue)}
                  class={["swatch", color]}
                  phx-click="start_color"
                  phx-value-color={color}
                  phx-target={@myself}
                >
                  {String.capitalize(color)}
                </a>
              </div>
            </section>
          <% {:drawn, card} -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">You drew a {Card.label(card)}</h2>
              <div class="drawn"><.card card={card} /></div>
              <div class="actions">
                <button class="btn btn-primary" phx-click="play" phx-value-id={card.id} phx-target={@myself}>
                  Play it
                </button>
                <button class="btn btn-secondary" phx-click="keep" phx-target={@myself}>Keep it</button>
              </div>
            </section>
          <% nil -> %>
        <% end %>
      <% end %>
    </div>
    """
  end
end
