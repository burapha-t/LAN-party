defmodule LanParty.LiarsDice.Rules do
  @moduledoc """
  Liar's Dice, free-form (docs/liars-dice/README.md): the server rolls, keeps each player's dice,
  and decides who is out and who won. Bids, turns and "Liar!" happen out loud, so phones have no
  moves. The table rolls, picks the face to count, and takes dice. Pure functions, no processes.
  See docs/liars-dice/design.md §4.
  """
  @behaviour LanParty.Game

  @start_dice 5

  defstruct players: [], dice: %{}, roll: 1, face: nil, winner: nil, roller: nil

  @type token :: String.t()
  @type t :: %__MODULE__{
          players: [token],
          dice: %{token => [1..6]},
          roll: pos_integer,
          face: nil | 2..6,
          winner: nil | token,
          roller: (non_neg_integer -> [1..6])
        }

  @impl true
  def new(players, _settings, opts) when length(players) >= 2 do
    # A remote capture, so a running game survives the dev server reloading this module.
    roller = Keyword.get(opts, :roller, &__MODULE__.random_dice/1)
    dice = Map.new(players, &{&1, roll_dice(roller, @start_dice)})
    %__MODULE__{players: players, dice: dice, roller: roller}
  end

  @doc "Rolls `n` dice."
  def random_dice(n), do: for(_ <- 1..n//1, do: :rand.uniform(6))

  @impl true
  def apply_action(_game, _token, _action), do: {:error, :no_actions}

  @impl true
  def table_action(%__MODULE__{} = game, :roll) do
    dice =
      Map.new(game.dice, fn {token, dice} -> {token, roll_dice(game.roller, length(dice))} end)

    {:ok, %{game | dice: dice, roll: game.roll + 1, face: nil}}
  end

  def table_action(%__MODULE__{} = game, {:count, face}) when face in 2..6,
    do: {:ok, %{game | face: face}}

  def table_action(%__MODULE__{}, {:count, _face}), do: {:error, :bad_face}

  def table_action(%__MODULE__{} = game, {:take_die, token}) do
    case Map.fetch(game.dice, token) do
      :error ->
        {:error, :not_in_game}

      {:ok, []} ->
        {:error, :no_dice}

      # The dice are sorted, so the last one is the highest.
      {:ok, dice} ->
        {:ok, check_winner(%{game | dice: Map.put(game.dice, token, Enum.drop(dice, -1))})}
    end
  end

  def table_action(%__MODULE__{}, _action), do: {:error, :unknown_action}

  @impl true
  def remove_player(%__MODULE__{} = game, token) do
    check_winner(%{
      game
      | players: List.delete(game.players, token),
        dice: Map.delete(game.dice, token)
    })
  end

  @impl true
  def winner(%__MODULE__{winner: winner}), do: winner

  # Out players have no dice, and rolling none gives none.
  defp roll_dice(_roller, 0), do: []
  defp roll_dice(roller, n), do: Enum.sort(roller.(n))

  # The game ends as soon as exactly one player has dice.
  defp check_winner(game) do
    case Enum.filter(game.players, &(game.dice[&1] != [])) do
      [last] -> %{game | winner: last}
      _more -> game
    end
  end
end
