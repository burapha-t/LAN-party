defmodule LanParty.Uno.Card do
  @moduledoc "One UNO card. `id` is unique in the deck, so two identical cards can be told apart."

  @enforce_keys [:id, :color, :value]
  defstruct [:id, :color, :value]

  @type color :: :red | :yellow | :green | :blue
  @type value :: 0..9 | :skip | :reverse | :draw2 | :wild | :wild_draw4
  @type t :: %__MODULE__{id: pos_integer(), color: color() | nil, value: value()}

  @colors [:red, :yellow, :green, :blue]
  @color_rank %{:red => 0, :yellow => 1, :green => 2, :blue => 3, nil => 4}

  def colors, do: @colors

  def wild?(%__MODULE__{value: value}), do: value in [:wild, :wild_draw4]

  @doc "Lowercase name for messages, e.g. red 7, blue +2, Wild +4."
  def label(%__MODULE__{value: :wild}), do: "Wild"
  def label(%__MODULE__{value: :wild_draw4}), do: "Wild +4"
  def label(%__MODULE__{color: color, value: value}), do: "#{color} #{value_label(value)}"

  defp value_label(:skip), do: "skip"
  defp value_label(:reverse), do: "reverse"
  defp value_label(:draw2), do: "+2"
  defp value_label(number), do: Integer.to_string(number)

  @doc "Hand order: red, yellow, green, blue, then wilds; within a color numbers, Skip, Reverse, +2."
  def sort(cards), do: Enum.sort_by(cards, &{@color_rank[&1.color], value_rank(&1.value), &1.id})

  defp value_rank(number) when is_integer(number), do: number
  defp value_rank(:skip), do: 10
  defp value_rank(:reverse), do: 11
  defp value_rank(:draw2), do: 12
  defp value_rank(:wild), do: 13
  defp value_rank(:wild_draw4), do: 14
end
