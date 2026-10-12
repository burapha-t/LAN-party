defmodule LanParty.Undercover.Pairs do
  @moduledoc """
  Reads Undercover's word list (priv/undercover/pairs.txt, docs/undercover/README.md "Words"): one
  pair per line, `Coffee | Tea`. Blank lines and lines starting with `#` are skipped. The Rules module
  calls this while it compiles, so a line that isn't exactly two non-empty words raises there, and a
  broken list fails the build instead of the party.
  """

  @doc "The text of the file as `[{word, word}]`. `source` names the file in error messages."
  def parse!(text, source \\ "pairs") do
    # A byte order mark (some Windows editors add one) is not a comment or a word.
    pairs =
      text
      |> String.trim_leading("﻿")
      |> String.split(~r/\R/)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {line, number} ->
        case String.trim(line) do
          "" -> []
          "#" <> _comment -> []
          line -> [pair!(line, source, number)]
        end
      end)

    if pairs == [], do: raise(ArgumentError, "#{source}: no word pairs")
    pairs
  end

  defp pair!(line, source, number) do
    case line |> String.split("|") |> Enum.map(&String.trim/1) do
      [a, b] when a != "" and b != "" ->
        {a, b}

      _bad ->
        raise ArgumentError,
              "#{source}, line #{number}: expected \"Word | Word\", got: #{inspect(line)}"
    end
  end
end
