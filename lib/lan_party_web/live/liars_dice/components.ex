defmodule LanPartyWeb.LiarsDice.Components do
  @moduledoc """
  Dice for the Liar's Dice screens: a flat die face (the table's face picker, the shelf box) and a 3D
  die (the phone). Markup follows docs/mockups/redesign/liars-dice/; the styles are the redesign
  stylesheet's "Liar's Dice" section.
  """
  use Phoenix.Component

  @doc "A flat die face: pips on a 3x3 grid."
  attr :value, :integer, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def face(assigns) do
    ~H"""
    <span class={["pips", "n#{@value}", @class]} {@rest}><i :for={_ <- 1..@value}></i></span>
    """
  end

  @doc """
  A 3D die showing `value`. `rolling` plays the roll animation when the die first appears (design.md
  §5); `state` lights it up ("lit") or dims it ("dim") during a count.
  """
  attr :id, :string, default: nil
  attr :value, :integer, required: true
  attr :rolling, :boolean, default: false
  attr :state, :string, default: nil, values: [nil, "lit", "dim"]

  def die(assigns) do
    ~H"""
    <span
      id={@id}
      class={["die", "v#{@value}", @rolling && "rolling", @state]}
      role="img"
      aria-label={@value}
    >
      <span class="cube" aria-hidden="true">
        <.face :for={side <- 1..6} value={side} class={"s#{side}"} />
      </span>
    </span>
    """
  end
end
