defmodule LanParty.Uno.Rules do
  @moduledoc """
  Every UNO rule, as pure functions over a game struct. No processes, no timers.
  The rules are in docs/uno/README.md; how they map to code is in docs/uno/design.md §6.
  """

  @behaviour LanParty.Game

  alias LanParty.Uno.{Card, Deck}

  @hand_size 7

  defstruct players: [],
            hands: %{},
            draw_pile: [],
            discard: [],
            color: nil,
            current: nil,
            direction: 1,
            settings: %{},
            jump_in_open: false,
            pending: nil,
            last_played_by: nil,
            last_challenge: nil,
            winner: nil

  @type token :: String.t()
  @type t :: %__MODULE__{}

  def default_settings do
    %{stack_plus2: false, stack_plus4: false, seven_zero: false, jump_in: false}
  end

  ## Setup

  @doc """
  Deals 7 cards to each player and flips the starting card.
  Options (for tests): `:deck` (cards in draw order) and `:first_player`.
  """
  def new(players, settings, opts \\ []) when length(players) >= 2 do
    deck = Keyword.get_lazy(opts, :deck, fn -> Deck.shuffle(Deck.new()) end)
    first = Keyword.get_lazy(opts, :first_player, fn -> Enum.random(players) end)
    {hands, draw_pile} = deal(players, deck)

    flip_start_card(%__MODULE__{
      players: players,
      hands: hands,
      draw_pile: draw_pile,
      current: first,
      settings: Map.merge(default_settings(), settings)
    })
  end

  defp deal(players, deck) do
    Enum.reduce(players, {%{}, deck}, fn player, {hands, cards} ->
      {hand, rest} = Enum.split(cards, @hand_size)
      {Map.put(hands, player, hand), rest}
    end)
  end

  # A +4 can't start the game: it goes to the bottom of the draw pile.
  defp flip_start_card(%{draw_pile: [%Card{value: :wild_draw4} = card | rest]} = game) do
    flip_start_card(%{game | draw_pile: rest ++ [card]})
  end

  defp flip_start_card(%{draw_pile: [card | rest]} = game) do
    start_effect(%{game | draw_pile: rest, discard: [card], color: card.color}, card)
  end

  defp start_effect(game, %Card{value: :wild}), do: %{game | pending: {:start_color, game.current}}
  defp start_effect(game, %Card{value: :skip}), do: %{game | current: step(game, game.current, 1)}
  defp start_effect(game, %Card{value: :reverse}), do: %{game | direction: -game.direction}
  defp start_effect(game, %Card{value: :draw2}), do: %{game | pending: penalty(2, :draw2, nil)}
  defp start_effect(game, _number), do: game

  ## Queries

  def top_card(%__MODULE__{discard: [top | _]}), do: top
  def winner(%__MODULE__{winner: winner}), do: winner

  @doc "The player after `from` in the direction of play."
  def next_player(game, from), do: step(game, from, 1)

  @doc "The draw cards the player facing a penalty may stack on it, given the house rules."
  def stack_options(%__MODULE__{pending: {:penalty, %{top: top}}, settings: settings}) do
    both = settings.stack_plus2 and settings.stack_plus4

    case top do
      :draw2 -> if(settings.stack_plus2, do: [:draw2], else: []) ++ if(both, do: [:wild_draw4], else: [])
      :draw4 -> if(both, do: [:draw2], else: []) ++ if(settings.stack_plus4, do: [:wild_draw4], else: [])
    end
  end

  def stack_options(%__MODULE__{}), do: []

  ## Actions

  @doc "Applies a phone action. Returns `{:ok, game}` or `{:error, reason}`."
  def apply_action(%__MODULE__{winner: winner}, _token, _action) when not is_nil(winner),
    do: {:error, :game_over}

  def apply_action(%__MODULE__{} = game, token, action) do
    if Map.has_key?(game.hands, token),
      do: do_action(%{game | last_challenge: nil}, token, action),
      else: {:error, :not_in_game}
  end

  defp do_action(game, token, {:choose_color, color}) do
    cond do
      game.pending != {:start_color, token} -> {:error, :not_now}
      color not in Card.colors() -> {:error, :invalid_color}
      true -> {:ok, %{game | color: color, pending: nil}}
    end
  end

  defp do_action(game, token, {:play, card_id, opts}) when is_map(opts) do
    with {:ok, card} <- find_card(game, token, card_id),
         :ok <- check_play(game, token, card),
         :ok <- check_opts(game, token, card, opts) do
      {:ok, play(game, token, card, opts)}
    end
  end

  defp do_action(game, token, :draw) do
    with :ok <- check_turn(game, token),
         :ok <- check_no_pending(game) do
      {game, drawn} = draw_cards(%{game | jump_in_open: false}, token, 1)

      case drawn do
        [card] ->
          if matches?(game, card),
            do: {:ok, %{game | pending: {:drawn, token, card.id}}},
            else: {:ok, advance(game, token, 1)}

        [] ->
          {:ok, advance(game, token, 1)}
      end
    end
  end

  defp do_action(game, token, :keep) do
    case game.pending do
      {:drawn, ^token, _card_id} -> {:ok, advance(game, token, 1)}
      _other -> {:error, :not_now}
    end
  end

  defp do_action(game, token, :accept) do
    with :ok <- check_turn(game, token),
         {:penalty, %{total: total}} <- game.pending do
      {game, _cards} = draw_cards(%{game | jump_in_open: false}, token, total)
      {:ok, advance(game, token, 1)}
    else
      {:error, _reason} = error -> error
      _other -> {:error, :not_now}
    end
  end

  defp do_action(game, token, :challenge) do
    with :ok <- check_turn(game, token),
         {:penalty, %{total: total, challenge: %{by: by, legal: legal, color: color}}} <- game.pending do
      game = %{game | jump_in_open: false, last_challenge: %{challenger: token, by: by, legal: legal, color: color}}

      if legal do
        {game, _cards} = draw_cards(game, token, total + 2)
        {:ok, advance(game, token, 1)}
      else
        {game, _cards} = draw_cards(game, by, total)
        {:ok, %{game | pending: nil}}
      end
    else
      {:error, _reason} = error -> error
      _other -> {:error, :not_now}
    end
  end

  # More action clauses go above this catch-all.
  defp do_action(_game, _token, _action), do: {:error, :unknown_action}

  ## Platform hooks (called by the Room)

  @doc """
  Takes a kicked player out of the round: their cards are shuffled into the draw pile, their turn
  passes, a penalty aimed at them is dropped, and a challenge of their +4 goes away.
  """
  def remove_player(%__MODULE__{} = game, token) do
    if token in game.players do
      next = step(game, token, 1)

      game = %{
        game
        | players: List.delete(game.players, token),
          hands: Map.delete(game.hands, token),
          draw_pile: Deck.shuffle(game.draw_pile ++ Map.fetch!(game.hands, token))
      }

      if game.current == token,
        do: %{game | current: next, pending: pending_after_leave(game.pending, next)},
        else: %{game | pending: drop_challenge_by(game.pending, token)}
    else
      game
    end
  end

  @doc "Referee override: the player draws `n` cards. Nothing else changes."
  def draw_for(%__MODULE__{} = game, token, n) when is_integer(n) and n > 0 do
    if Map.has_key?(game.hands, token) do
      {game, _cards} = draw_cards(game, token, n)
      {:ok, game}
    else
      {:error, :not_in_game}
    end
  end

  @doc "A table control during a round. UNO has one: \"draw for player\", 1 to 10 cards."
  def table_action(%__MODULE__{} = game, {:draw_for, token, n}) when is_integer(n) and n in 1..10,
    do: draw_for(game, token, n)

  def table_action(%__MODULE__{}, {:draw_for, _token, _n}), do: {:error, :bad_amount}
  def table_action(%__MODULE__{}, _action), do: {:error, :unknown_action}

  defp pending_after_leave({:start_color, _token}, next), do: {:start_color, next}
  defp pending_after_leave(_pending, _next), do: nil

  defp drop_challenge_by({:penalty, %{challenge: %{by: token}} = penalty}, token),
    do: {:penalty, %{penalty | challenge: nil}}

  defp drop_challenge_by(pending, _token), do: pending

  ## Helpers

  defp find_card(game, token, card_id) do
    case Enum.find(game.hands[token], &(&1.id == card_id)) do
      nil -> {:error, :not_in_hand}
      card -> {:ok, card}
    end
  end

  defp check_play(game, token, card) do
    cond do
      jump_in?(game, card) -> :ok
      game.current != token -> {:error, :not_your_turn}
      true -> check_turn_play(game, token, card)
    end
  end

  # Jump-in: an identical card (same color and value) while the window is open. Wilds have no color.
  defp jump_in?(game, card) do
    top = top_card(game)

    game.settings.jump_in and game.jump_in_open and not Card.wild?(card) and
      card.color == top.color and card.value == top.value
  end

  # A play on your own turn, given what the game is waiting for.
  defp check_turn_play(game, token, card) do
    card_id = card.id

    case game.pending do
      nil -> if matches?(game, card), do: :ok, else: {:error, :does_not_match}
      {:drawn, ^token, ^card_id} -> :ok
      {:drawn, _token, _card_id} -> {:error, :play_drawn_or_keep}
      {:start_color, _token} -> {:error, :choose_start_color}
      {:penalty, penalty} -> if can_stack?(game, penalty, card), do: :ok, else: {:error, :resolve_penalty}
    end
  end

  defp check_opts(game, token, card, opts) do
    cond do
      Card.wild?(card) and Map.get(opts, :color) not in Card.colors() ->
        {:error, :choose_color}

      game.settings.seven_zero and card.value == 7 and not swap_target?(game, token, Map.get(opts, :swap_with)) ->
        {:error, :choose_player}

      true ->
        :ok
    end
  end

  defp swap_target?(game, token, target), do: target != token and target in game.players

  defp check_turn(%{current: token}, token), do: :ok
  defp check_turn(_game, _token), do: {:error, :not_your_turn}

  defp check_no_pending(%{pending: nil}), do: :ok
  defp check_no_pending(%{pending: {:penalty, _}}), do: {:error, :resolve_penalty}
  defp check_no_pending(%{pending: {:start_color, _}}), do: {:error, :choose_start_color}
  defp check_no_pending(%{pending: {:drawn, _, _}}), do: {:error, :play_drawn_or_keep}

  defp matches?(game, card) do
    top = top_card(game)
    Card.wild?(card) or card.color == game.color or card.value == top.value
  end

  # A +2 on a +4 must match the color chosen for the +4.
  defp can_stack?(game, %{top: top}, card) do
    card.value in stack_options(game) and
      not (top == :draw4 and card.value == :draw2 and card.color != game.color)
  end

  defp play(game, token, card, opts) do
    # Recorded for a possible +4 challenge: legal only if no card of the color before it was held.
    plus4 = %{legal: not holds_color?(game.hands[token], game.color, card.id), color: game.color}
    hand = Enum.reject(game.hands[token], &(&1.id == card.id))

    game = %{
      game
      | hands: Map.put(game.hands, token, hand),
        discard: [card | game.discard],
        color: if(Card.wild?(card), do: Map.fetch!(opts, :color), else: card.color),
        current: token,
        jump_in_open: true,
        last_played_by: token
    }

    # Winning ends the round at once; the winning card's effect isn't applied.
    if hand == [],
      do: %{game | winner: token, pending: nil},
      else: effect(game, token, card, opts, plus4)
  end

  defp holds_color?(hand, color, except_id),
    do: Enum.any?(hand, &(&1.id != except_id and &1.color == color))

  # One clause per card value, catch-all last.
  defp effect(game, token, %Card{value: :draw2}, _opts, _plus4),
    do: add_penalty(game, token, penalty_total(game.pending) + 2, :draw2, nil)

  defp effect(game, token, %Card{value: :wild_draw4}, _opts, plus4) do
    existing = penalty_total(game.pending)
    # Only a +4 that starts a penalty can be challenged (README "Stacking").
    challenge = if existing == 0, do: Map.put(plus4, :by, token)
    add_penalty(game, token, existing + 4, :draw4, challenge)
  end

  defp effect(%{settings: %{seven_zero: true}} = game, token, %Card{value: 7}, opts, _plus4) do
    other = Map.fetch!(opts, :swap_with)
    hands = game.hands |> Map.put(token, game.hands[other]) |> Map.put(other, game.hands[token])
    advance(%{game | hands: hands}, token, 1)
  end

  defp effect(%{settings: %{seven_zero: true}} = game, token, %Card{value: 0}, _opts, _plus4) do
    hands = Map.new(game.players, fn player -> {step(game, player, 1), game.hands[player]} end)
    advance(%{game | hands: hands}, token, 1)
  end

  defp effect(game, token, %Card{value: :skip}, _opts, _plus4), do: advance(game, token, 2)

  defp effect(game, token, %Card{value: :reverse}, _opts, _plus4) do
    game = %{game | direction: -game.direction}
    advance(game, token, if(length(game.players) == 2, do: 2, else: 1))
  end

  defp effect(game, token, _card, _opts, _plus4), do: advance(game, token, 1)

  defp advance(game, from, steps), do: %{game | current: step(game, from, steps), pending: nil}

  defp add_penalty(game, token, total, top, challenge),
    do: %{game | current: step(game, token, 1), pending: penalty(total, top, challenge)}

  defp penalty_total({:penalty, %{total: total}}), do: total
  defp penalty_total(_pending), do: 0

  defp draw_cards(game, token, n) do
    {cards, game} = take(game, n, [])
    {%{game | hands: Map.update!(game.hands, token, &(&1 ++ cards))}, cards}
  end

  defp take(game, 0, acc), do: {Enum.reverse(acc), game}

  defp take(%{draw_pile: [card | rest]} = game, n, acc),
    do: take(%{game | draw_pile: rest}, n - 1, [card | acc])

  # Draw pile empty: the discard pile minus its top card becomes the new draw pile.
  defp take(%{draw_pile: [], discard: [top | under]} = game, n, acc) when under != [],
    do: take(%{game | draw_pile: Deck.shuffle(under), discard: [top]}, n, acc)

  # Both piles empty: draw what there was.
  defp take(game, _n, acc), do: {Enum.reverse(acc), game}

  defp step(%{players: players, direction: direction}, from, steps) do
    index = Enum.find_index(players, &(&1 == from))
    Enum.at(players, Integer.mod(index + direction * steps, length(players)))
  end

  defp penalty(total, top, challenge), do: {:penalty, %{total: total, top: top, challenge: challenge}}
end
