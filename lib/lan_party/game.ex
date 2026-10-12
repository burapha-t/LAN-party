defmodule LanParty.Game do
  @moduledoc """
  What the Room calls on the picked game (docs/liars-dice/design.md §3). Each playable game's rules
  module implements it, and the Room finds that module with `LanParty.Games.module/1`. Every game
  struct has a `players` list of tokens; the Room's "one seated player left" check reads it.
  """

  @type token :: String.t()
  @type game :: struct()

  @doc "A new game for these seated tokens. `opts` is the Room's `game_opts` (tests fix the deck or the dice)."
  @callback new(players :: [token], settings :: map, opts :: keyword) :: game

  @doc "A phone's move."
  @callback apply_action(game, token, action :: term) :: {:ok, game} | {:error, atom}

  @doc "A table control during a game."
  @callback table_action(game, action :: term) :: {:ok, game} | {:error, atom}

  @doc "A kicked player leaves the game."
  @callback remove_player(game, token) :: game

  @doc "`nil`, or the token of the player who won."
  @callback winner(game) :: token | nil
end
