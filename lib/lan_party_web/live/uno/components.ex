defmodule LanPartyWeb.Uno.Components do
  @moduledoc "UNO pieces shared by the phone and table screens. Markup copied from mockups/."
  use Phoenix.Component

  alias LanParty.Uno.Card

  @doc "A card to look at (the pile, a result screen)."
  attr :card, Card, required: true
  attr :rest, :global

  def card(assigns) do
    ~H"""
    <span class={["card", color_class(@card)]} role="img" aria-label={aria_label(@card)} {@rest}>
      <.face card={@card} />
    </span>
    """
  end

  @doc "A card in your hand that you can tap."
  attr :card, Card, required: true
  attr :rest, :global

  def card_button(assigns) do
    ~H"""
    <a class={["card", color_class(@card)]} role="button" aria-label={aria_label(@card)} {@rest}>
      <.face card={@card} />
    </a>
    """
  end

  @doc "A message with an OK to dismiss it."
  attr :message, :string, required: true
  attr :rest, :global

  def toast(assigns) do
    ~H"""
    <a class="toast" role="alert" {@rest}><span>{@message}</span><span>OK</span></a>
    """
  end

  def color_class(%Card{color: nil}), do: "black"
  def color_class(%Card{color: color}), do: Atom.to_string(color)

  def aria_label(card), do: String.capitalize(Card.label(card))

  defp face(%{card: %Card{value: :wild}} = assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval quad"></span><span class="idx"><span class="dot4"></span></span><span class="idx br"><span class="dot4"></span></span></span>
    """
  end

  defp face(%{card: %Card{value: :wild_draw4}} = assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class="mini" style="--mc:var(--yellow);--dx:calc(var(--cw)*-0.14);--dy:calc(var(--cw)*0.11)"></span><span class="mini" style="--mc:var(--green);--dx:calc(var(--cw)*-0.05);--dy:calc(var(--cw)*0.04)"></span><span class="mini" style="--mc:var(--blue);--dx:calc(var(--cw)*0.04);--dy:calc(var(--cw)*-0.03)"></span><span class="mini" style="--mc:var(--red);--dx:calc(var(--cw)*0.13);--dy:calc(var(--cw)*-0.1)"></span><span class="idx">+4</span><span class="idx br">+4</span></span>
    """
  end

  defp face(%{card: %Card{value: :draw2}} = assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class="mini" style="--dx:calc(var(--cw)*-0.06);--dy:calc(var(--cw)*0.06)"></span><span class="mini" style="--dx:calc(var(--cw)*0.06);--dy:calc(var(--cw)*-0.06)"></span><span class="idx">+2</span><span class="idx br">+2</span></span>
    """
  end

  defp face(%{card: %Card{value: symbol}} = assigns) when symbol in [:skip, :reverse] do
    assigns = assign(assigns, :href, "##{symbol}")

    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class="big"><svg><use href={@href} /></svg></span><span class="idx"><svg><use href={@href} /></svg></span><span class="idx br"><svg><use href={@href} /></svg></span></span>
    """
  end

  defp face(assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class={["big", @card.value in [6, 9] && "u"]}><span>{@card.value}</span></span><span class="idx">{@card.value}</span><span class="idx br">{@card.value}</span></span>
    """
  end
end
