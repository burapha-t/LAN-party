defmodule LanPartyWeb.Undercover.Components do
  @moduledoc """
  The paper slip for the Undercover screens: your word on the phone, and the two small slips on the
  shelf box. The styles are the "Undercover" section of assets/css/app.css.
  """
  use Phoenix.Component

  @doc """
  A slip of paper with one word on it. The word's size steps down as it gets longer, so even a long
  word or two short words fit on one line of a narrow phone. `dealt` plays the slide-in when the slip
  first appears (a new deal); give the slip an id that changes with each deal, so LiveView makes a
  new element and the animation plays again.
  """
  attr :id, :string, default: nil
  attr :word, :string, required: true
  attr :dealt, :boolean, default: false
  attr :rest, :global

  def slip(assigns) do
    ~H"""
    <span id={@id} class={["slip", @dealt && "dealt"]} {@rest}>
      <span class={["slip-word", size(@word)]}>{@word}</span>
    </span>
    """
  end

  # By length, with the sizes in the stylesheet. Spaces count: "Swimming pool" is a long word to fit.
  defp size(word) do
    case String.length(word) do
      length when length <= 4 -> "size-xl"
      length when length <= 6 -> "size-l"
      length when length <= 10 -> "size-m"
      length when length <= 13 -> "size-s"
      _longer -> "size-xs"
    end
  end
end
