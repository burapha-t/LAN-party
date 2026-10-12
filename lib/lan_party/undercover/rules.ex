defmodule LanParty.Undercover.Rules do
  @moduledoc """
  Undercover, free-form (docs/undercover/README.md): the server only deals words. Every player gets
  one word of a pair, and the undercovers get the other one. Nobody is told their role. Describing,
  voting and revealing happen out loud, so phones have no moves, and the table only rerolls. Pure
  functions, no processes.

  The word list loads while this module compiles (`priv/undercover/pairs.txt`, see `Pairs`). The game
  keeps indexes into it, never the list itself: the Room's whole state is broadcast to every page on
  each change.
  """
  @behaviour LanParty.Game

  alias LanParty.Undercover.Pairs

  @pairs_file Path.expand("../../../priv/undercover/pairs.txt", __DIR__)
  @external_resource @pairs_file
  @pairs Pairs.parse!(File.read!(@pairs_file), "priv/undercover/pairs.txt")

  # `pair` is the index of the pair on the table, `deck` the indexes still to deal this pass.
  # `pairs` is a word list given to `new/3` (tests); nil means the file's list.
  # The shuffle puts the pairs in order, picks the undercovers and orders a pair's two words.
  defstruct players: [],
            words: %{},
            deal: 0,
            undercovers: 0,
            pair: nil,
            deck: [],
            pairs: nil,
            shuffle: nil

  @type token :: String.t()
  @type t :: %__MODULE__{
          players: [token],
          words: %{token => String.t()},
          deal: pos_integer,
          undercovers: pos_integer,
          pair: nil | non_neg_integer,
          deck: [non_neg_integer],
          pairs: nil | [{String.t(), String.t()}],
          shuffle: (list -> list)
        }

  @doc "Every pair in the word list."
  def pairs, do: @pairs

  @impl true
  def new(players, _settings, opts) when length(players) >= 3 do
    # A remote capture, so a running game survives the dev server reloading this module.
    shuffle = Keyword.get(opts, :shuffle, &Enum.shuffle/1)
    deal(%__MODULE__{players: players, pairs: Keyword.get(opts, :pairs), shuffle: shuffle})
  end

  @impl true
  def apply_action(_game, _token, _action), do: {:error, :no_actions}

  @impl true
  def table_action(%__MODULE__{} = game, :reroll), do: {:ok, deal(game)}
  def table_action(%__MODULE__{}, _action), do: {:error, :unknown_action}

  # The kicked player's word leaves the game. The dealt count stays, so a kick doesn't give away
  # what the kicked player was.
  @impl true
  def remove_player(%__MODULE__{} = game, token) do
    %{game | players: List.delete(game.players, token), words: Map.delete(game.words, token)}
  end

  # The Room's "one seated player left" rule is the only way a game ends.
  @impl true
  def winner(%__MODULE__{}), do: nil

  ## A deal

  defp deal(game) do
    {pair, deck} = next_pair(game)
    [civilian_word, undercover_word] = game.shuffle.(Tuple.to_list(pair_at(game, pair)))
    count = undercover_count(length(game.players))
    undercovers = game.players |> game.shuffle.() |> Enum.take(count)

    words =
      Map.new(
        game.players,
        &{&1, if(&1 in undercovers, do: undercover_word, else: civilian_word)}
      )

    %{game | words: words, deal: game.deal + 1, undercovers: count, pair: pair, deck: deck}
  end

  # 1 undercover with 3 to 5 players, 2 with 6 to 8, counted from the players at deal time.
  defp undercover_count(players) when players >= 6, do: 2
  defp undercover_count(_players), do: 1

  # No pair repeats until all have been dealt. Then they are shuffled again, with the pair just dealt
  # kept for last, so a reroll never shows the same pair twice in a row.
  defp next_pair(%{deck: [index | rest]}), do: {index, rest}

  defp next_pair(game) do
    others = Enum.to_list(0..(pair_count(game) - 1)//1) -- List.wrap(game.pair)
    [index | rest] = game.shuffle.(others) ++ List.wrap(game.pair)
    {index, rest}
  end

  defp pair_at(game, index), do: Enum.at(game.pairs || @pairs, index)
  defp pair_count(game), do: length(game.pairs || @pairs)
end
