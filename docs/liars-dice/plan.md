# Liar's Dice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Liar's Dice the second playable game: the table picks it, 2–8 phones get 5 dice each with
a rolling animation, and the group plays a full game to a winner using only Roll, the face picker and
"take a die" on the table.

**Architecture:** The Room stops calling `LanParty.Uno.Rules` directly and forwards to the picked game's
rules module through a small behaviour (`LanParty.Game`). Liar's Dice is a pure rules module
(`LanParty.LiarsDice.Rules`) plus a view module, and one pair of LiveComponents (phone, table) rendered
by the existing `PlayerLive` / `TableLive`. The roll animation is pure CSS that is already in the
redesign stylesheet. No JS.

**Tech Stack:** Elixir 1.20.4 / OTP 29, Phoenix 1.8, Phoenix LiveView 1.1.33, LazyHTML in tests. No new
dependencies.

**Spec:** `docs/liars-dice/design.md` (approved: the user started implementation on 2026-10-12). Rules:
`docs/liars-dice/README.md`. Platform: `CLAUDE.md`. Screens: `docs/mockups/redesign/liars-dice/`
(markup and copy), plus `docs/mockups/platform/table/index.html` for the shelf box. Read all of them.

## How this plan is run

The user assigned an orchestrator (the session that wrote this plan) and two implementer subagents,
**dice-a** and **dice-b**. A separate Claude session is redesigning UNO at the same time, so file
ownership matters.

| Phase | dice-a | dice-b | Orchestrator |
|---|---|---|---|
| 0 | | | Task 0: `liars-dice` fast-forwarded onto the UNO redesign (`f02f906`); this plan and `lib/lan_party/game.ex` |
| 1 (in parallel) | Task 1: the Room forwards to the game | Tasks 2–3: Liar's Dice rules, views, dice components | merges both into `liars-dice` |
| 2 (sequential) | Task 4: Liar's Dice playable, Room tests | waits | merges |
| 3 (in parallel) | Task 5: table screens and shelf box | Task 6: phone screens | merges both |
| 4 | | | Task 7: visual check, docs, ask before merging into `main` |

**Worktrees** (all share the deps in `D:\project\LAN-party\deps`):

| Who | Directory | Branch |
|---|---|---|
| orchestrator | `D:\project\LAN-party-dice` | `liars-dice` |
| dice-a | `D:\project\LAN-party-dice-a` | `ld-a` |
| dice-b | `D:\project\LAN-party-dice-b` | `ld-b` |

The orchestrator creates the worktrees and moves commits between them. **Never touch
`D:\project\LAN-party` (the UNO session works there) or the `main` branch.**

**Running mix** (PowerShell; Elixir isn't on PATH):

```powershell
$env:Path = "C:\Program Files\Erlang OTP\bin;C:\Program Files\Elixir\bin;" + $env:Path; $env:MIX_DEPS_PATH = "D:\project\LAN-party\deps"; Set-Location D:\project\LAN-party-dice-a; mix test
```

(Use your own worktree directory.) The first run in a new worktree compiles the deps (1–2 minutes).

**The UNO redesign session owns** `assets/css/app.css`, `lib/lan_party_web/components/layouts*`,
`lib/lan_party_web/live/uno/*`, the platform screens, and `lib/lan_party_web/live/lobby_components.ex`.
Its work is already on this branch (commit `f02f906`): `app.css` is the redesign stylesheet, including
the Liar's Dice section, `.lobby.solo`, `.seat.out` and the shelf's `.box-dice` rules. It agreed that
this plan may make **only** these edits to its files:
- `uno/table_component.ex`: the one `Room.draw_for(…)` call becomes `Room.table_act({:draw_for, …})` (Task 1).
- `table_live.ex`: the Liar's Dice box and side-panel entry on the shelf, and the Liar's Dice
  `live_component` block (Task 5).
- `player_live.ex`: the Liar's Dice `live_component` block (Task 6).
- `lobby_components.ex`: the queue wording "Waiting for this round to end" becomes "Waiting for this
  game to end" (Task 6; design.md §2, item 11).

If a screen needs a CSS change, tell the orchestrator, who asks the UNO session. Don't edit CSS.

**`LanPartyWeb.LobbyComponents`** (already on the branch; Tasks 5 and 6 use it):

| Function | Attrs | Renders |
|---|---|---|
| `avatar/1` | `room`, `token` | `<span class="avatar pN" aria-hidden="true">X</span>`; N = rem(index in `room.order`, 8) + 1, X = the upcased first letter of the name. A token no longer in the room gets a bare avatar with no initial, so guard it with `:if={@room.people[token]}`. |
| `players_panel/1` | `room` | The table lobby's Players panel: `section.panel`, "N of 8 seats taken", the roster with free seats, `p.wait` "Waiting for players to join" under 2 seated, `p.lobby-note` "Waiting for a seat: …". |
| `phone_lobby/1` | `room`, `token` | "You're in." / "Waiting for the table to start" / the players. |
| `phone_queue/1` | `room`, `token` | "You're #N in line." … |

The redesign's buttons are `.btn` (sun yellow, the main action), `.btn-white`, `.btn-quiet` and the
size `.btn-big`. There is no `.btn-primary` or `.btn-secondary` any more. `PlayerLive`'s header bar
(avatar, "Playing as", the game's wordmark) is already done; game components render below it.

## Global Constraints

- Work only in your own worktree, on your own branch. Commit after each task with
  `git add <exact paths>` (never `git add -A` or `.`), and end the message with
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Never push, never touch `main`.
- **Never edit:** `assets/**`, `lib/lan_party_web/components/**`, `docs/mockups/**`, `CLAUDE.md`. In
  `lib/lan_party_web/live/uno/**`, `lobby_components.ex`, `player_live.ex` and `table_live.ex`, make
  only the edits your task lists.
- Before every commit: `mix test` passes and `mix compile --warnings-as-errors` succeeds.
- Run `mix format <file>` only on files you create. The existing code isn't mix-formatted, so don't
  reformat files you only edit. Check `git diff --stat` before committing: it should list only the
  files your task names.
- Liar's Dice is free-form: the server never tracks bids, turns or who called "Liar!". Phones have no
  actions. Starting dice: **5**. Faces that can be counted: **2 to 6**. **1s are wild.**
- The table never renders a die's value (no `.die`, no dice values). A phone renders only its own dice.
- Markup and copy follow `docs/mockups/redesign/liars-dice/` exactly: same elements, class names and
  text. Differences on purpose: real `<button>`s for Start game, Roll, Reset, Cancel, Remove, End game
  and Play again (the mockups use links), and `<p>` where a mockup uses a link only to go between mockup
  pages (`.counting`, `.dice-total`, `.dice-hint`). Clickable seats and face buttons stay
  `<a phx-click>`, the codebase's convention (the root layout gives `[phx-click]` a pointer cursor).
- No JS hooks. The roll animation is the stylesheet's `.die.rolling`.
- The existing UNO behavior and its tests must keep passing (147 at the start).
- No generic framework: `LanParty.Game` has exactly the five callbacks in `design.md` §3.

## Review Focus

1. **Double tap on Remove, or two tables taking the same last die:** exactly one die is taken, nothing
   crashes, and a stale tap shows "That didn't work. Try again." Tests in Task 2 (`:no_dice`) and Task 5.
2. **Roll animation timing:** a phone that reloads or wakes mid-game shows its dice already landed, with
   no animation. A phone open at Start game sees the first roll animate, and so does the first roll of
   the *next* game, even on a phone that was opened mid-game. Tests in Task 6.
3. **The winner leaves after the game ends** (kicked while the result is showing): the table and the
   phones keep rendering ("Someone won"), with no crash on the avatar of a token that's no longer in the
   room. Tests in Tasks 5 and 6.
4. **Garbage table input** (an unknown table action, a face of "7" or "x", a tap on an Out or unknown
   player) is refused or ignored. It must never crash the Room, which would lose the whole night.
   Tests in Tasks 1, 2 and 5.
5. **The take-a-die panel goes stale** (its player lost their last die at another table, or left): the
   panel closes and never renders a nil name. Test in Task 5.

## File Structure

```
lib/lan_party/game.ex                                  # new (Task 0): the behaviour
lib/lan_party/games.ex                                 # Task 1: module/1; Task 4: Liar's Dice playable
lib/lan_party/room.ex                                  # Task 1: forwards to Games.module/1; table_act/1
lib/lan_party/uno/rules.ex                             # Task 1: @behaviour, table_action/2
lib/lan_party_web/live/uno/table_component.ex          # Task 1: draw for player calls Room.table_act/1
lib/lan_party_web/live/lobby_components.ex             # Task 6: the queue says "game", not "round"
lib/lan_party/liars_dice/rules.ex                      # new (Task 2): every Liar's Dice rule
lib/lan_party/liars_dice/view.ex                       # new (Task 2): what a phone / the table may see
lib/lan_party_web/live/liars_dice/components.ex        # new (Task 3): die (3D) and face (flat)
lib/lan_party_web/live/liars_dice/table_component.ex   # new (Task 5)
lib/lan_party_web/live/liars_dice/player_component.ex  # new (Task 6)
lib/lan_party_web/live/table_live.ex                   # Task 5: shelf box + aside, dispatch block
lib/lan_party_web/live/player_live.ex                  # Task 6: dispatch block
test/lan_party/games_test.exs                          # Tasks 1, 4
test/lan_party/room_test.exs                           # Task 1
test/lan_party/uno/rules_leave_test.exs                # Task 1
test/lan_party/liars_dice/rules_test.exs               # new (Task 2)
test/lan_party/liars_dice/view_test.exs                # new (Task 2)
test/lan_party/room_liars_dice_test.exs                # new (Task 4)
test/lan_party_web/live/liars_dice/components_test.exs # new (Task 3)
test/lan_party_web/live/liars_dice_table_test.exs      # new (Task 5)
test/lan_party_web/live/liars_dice_phone_test.exs      # new (Task 6)
```

---

### Task 0 (orchestrator): the plan and the behaviour

**Files:**
- Create: `lib/lan_party/game.ex`, `docs/liars-dice/plan.md`

Done by the orchestrator before Phase 1, so both implementers start from the same behaviour.

```elixir
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
```

---

### Task 1 (dice-a): the Room forwards to the picked game

**Files:**
- Modify: `lib/lan_party/games.ex`, `lib/lan_party/room.ex`, `lib/lan_party/uno/rules.ex`,
  `lib/lan_party_web/live/uno/table_component.ex` (one call only)
- Test: `test/lan_party/games_test.exs`, `test/lan_party/room_test.exs`, `test/lan_party/uno/rules_leave_test.exs`

**Interfaces:**
- Consumes: `LanParty.Game` (Task 0).
- Produces:
  - `LanParty.Games.module(id) :: module | nil`, e.g. `:uno` → `LanParty.Uno.Rules`.
  - `LanParty.Room.table_act(server \\ LanParty.Room, action) :: :ok | {:error, atom}`. During
    `:playing` it calls `module.table_action(game, action)`; otherwise `{:error, :not_now}`.
  - `LanParty.Room.draw_for/3` is removed (design.md §3). The UNO table calls
    `Room.table_act({:draw_for, token, n})` instead.
  - `LanParty.Uno.Rules.table_action(game, {:draw_for, token, n})`: n in 1..10 → `draw_for/3`;
    otherwise `{:error, :bad_amount}`; any other action → `{:error, :unknown_action}`.
  - After every phone action, table action and kick, the Room asks `module.winner/1`; a winner sets
    `phase: :finished, winner: token`.

- [x] **Step 1: Write the failing tests**

In `test/lan_party/games_test.exs`, add:

```elixir
  test "a playable game names its rules module" do
    assert Games.module(:uno) == LanParty.Uno.Rules
    assert Games.module(:quiplash) == nil
    assert Games.module(:chess) == nil
  end
```

In `test/lan_party/uno/rules_leave_test.exs`, add a new `describe` block after `describe "draw_for/3"`:

```elixir
  describe "table_action/2" do
    test "draw for player: 1 to 10 cards" do
      {:ok, after_draw} = Rules.table_action(game(), {:draw_for, "c", 3})
      assert length(after_draw.hands["c"]) == 5
      assert Rules.table_action(game(), {:draw_for, "c", 0}) == {:error, :bad_amount}
      assert Rules.table_action(game(), {:draw_for, "c", 11}) == {:error, :bad_amount}
      assert Rules.table_action(game(), {:draw_for, "zed", 2}) == {:error, :not_in_game}
    end

    test "anything else is refused" do
      assert Rules.table_action(game(), :roll) == {:error, :unknown_action}
    end
  end
```

In `test/lan_party/room_test.exs`, replace the test `"draw for player takes 1 to 10 cards"` with these
two tests (same `describe` block):

```elixir
    test "table controls go to the game's rules: draw for player takes 1 to 10 cards", %{room: room} do
      assert Room.table_act(room, {:draw_for, "t2", 0}) == {:error, :bad_amount}
      assert Room.table_act(room, {:draw_for, "t2", 11}) == {:error, :bad_amount}
      assert Room.table_act(room, {:draw_for, "t2", 2}) == :ok
      assert length(Room.get_state(room).game.hands["t2"]) == 9
    end

    test "a table control the game doesn't know is refused, and the Room keeps going", %{room: room} do
      assert Room.table_act(room, :roll) == {:error, :unknown_action}
      assert Room.get_state(room).phase == :playing
    end
```

And in the test `"actions outside a round are refused"`, add a last line:

```elixir
      assert Room.table_act(room, {:draw_for, "t2", 2}) == {:error, :not_now}
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `mix test test/lan_party/games_test.exs test/lan_party/uno/rules_leave_test.exs test/lan_party/room_test.exs`
Expected: FAIL. `Games.module/1`, `Rules.table_action/2` and `Room.table_act/2` are undefined.

- [x] **Step 3: Implement**

`lib/lan_party/games.ex`: give UNO its module and add `module/1`. Liar's Dice stays unplayable until
Task 4. Replace the moduledoc and the UNO entry, and add the function:

```elixir
  @moduledoc """
  The games on the table's "Select the game" screen (CLAUDE.md "Games"). A playable game names its
  rules module, which implements `LanParty.Game`. A list, not a framework.
  """

  @games [
    %{id: :uno, name: "UNO", playable?: true, module: LanParty.Uno.Rules},
    # ... the other entries unchanged ...
  ]

  # ... all/0, playable?/1, name/1 unchanged ...

  @doc "The rules module of a playable game, or nil."
  def module(id), do: Enum.find_value(@games, &(&1.id == id and &1[:module]))
```

`lib/lan_party/uno/rules.ex`: add `@behaviour LanParty.Game` right after the moduledoc. **Don't** add
`@impl` anywhere: once one callback has `@impl`, Elixir wants it on all of them, and this task changes
nothing else in UNO. Add after `draw_for/3`:

```elixir
  @doc "A table control during a round. UNO has one: \"draw for player\", 1 to 10 cards."
  def table_action(%__MODULE__{} = game, {:draw_for, token, n}) when is_integer(n) and n in 1..10,
    do: draw_for(game, token, n)

  def table_action(%__MODULE__{}, {:draw_for, _token, _n}), do: {:error, :bad_amount}
  def table_action(%__MODULE__{}, _action), do: {:error, :unknown_action}
```

`lib/lan_party/room.ex`:

1. Moduledoc, first lines: replace "Knows nothing about cards: UNO actions go to `LanParty.Uno.Rules`."
   with "Knows nothing about cards or dice: game moves go to the picked game's rules module (a
   `LanParty.Game`, found with `Games.module/1`)."
2. Keep `alias LanParty.Uno.Rules`. It's still used for UNO's house-rule settings, which stay
   night-wide (design.md §3).
3. Client API: replace the `draw_for` line with:

```elixir
  def table_act(server \\ __MODULE__, action), do: GenServer.call(server, {:table_act, action})
```

4. `handle_call({:act, ...}, _from, %{phase: :playing} = state)`: replace `Rules.apply_action(` with
   `game_module(state).apply_action(`.
5. `handle_call(:start_game, ...)`: replace `Rules.new(players, state.settings, state.game_opts)` with
   `game_module(state).new(players, state.settings, state.game_opts)`.
6. Delete both `handle_call({:draw_for, ...})` clauses and put these in their place:

```elixir
  def handle_call({:table_act, action}, _from, %{phase: :playing} = state) do
    case game_module(state).table_action(state.game, action) do
      {:ok, game} -> {:reply, :ok, state |> put_game(game) |> broadcast()}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:table_act, _action}, _from, state), do: {:reply, {:error, :not_now}, state}
```

7. `put_game/2`: replace `Rules.winner(game)` with `game_module(state).winner(game)`.
8. Replace `remove_from_round/2` with:

```elixir
  # The game's rules take the player out. A winner, or one seated player left, ends the game
  # (CLAUDE.md "Disconnects": last player left wins).
  defp remove_from_round(state, token) do
    game = game_module(state).remove_player(state.game, token)
    state = put_game(state, game)

    case {state.phase, game.players} do
      {:playing, [last]} -> %{state | phase: :finished, winner: last}
      _other -> state
    end
  end

  defp game_module(state), do: Games.module(state.game_id)
```

`lib/lan_party_web/live/uno/table_component.ex` (the UNO session agreed to this one change; touch
nothing else in the file): in `handle_event("confirm_draw_for", …)`, replace
`Room.draw_for(socket.assigns.draw_for, socket.assigns.amount)` with
`Room.table_act({:draw_for, socket.assigns.draw_for, socket.assigns.amount})`.
`test/lan_party_web/live/uno_table_test.exs` already covers that panel end to end.

- [x] **Step 4: Run all the tests**

Run: `mix test` then `mix compile --warnings-as-errors`
Expected: all pass (147 + 4 new = 151), no warnings. `grep -rn "draw_for(" lib test` finds only
`Uno.Rules.draw_for/3` and its tests.

- [x] **Step 5: Commit**

```powershell
git add lib/lan_party/games.ex lib/lan_party/room.ex lib/lan_party/uno/rules.ex lib/lan_party_web/live/uno/table_component.ex test/lan_party/games_test.exs test/lan_party/room_test.exs test/lan_party/uno/rules_leave_test.exs
git commit -m "feat: the Room forwards moves to the picked game's rules module" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2 (dice-b): Liar's Dice rules and views

**Files:**
- Create: `lib/lan_party/liars_dice/rules.ex`, `lib/lan_party/liars_dice/view.ex`
- Test: `test/lan_party/liars_dice/rules_test.exs`, `test/lan_party/liars_dice/view_test.exs`

**Interfaces:**
- Consumes: `LanParty.Game` (Task 0).
- Produces:
  - `%LanParty.LiarsDice.Rules{players: [token], dice: %{token => [1..6]} (sorted; [] = out), roll: pos_integer, face: nil | 2..6, winner: nil | token, roller: (n -> [1..6])}`
  - `Rules.new(players, settings, opts)`: `opts[:roller]` fixes the dice in tests (default `&Rules.random_dice/1`).
  - `Rules.table_action(game, :roll | {:count, face} | {:take_die, token})`: errors are `:bad_face`, `:not_in_game`, `:no_dice` and `:unknown_action`.
  - `Rules.apply_action/3` → always `{:error, :no_actions}`; `Rules.remove_player/2`; `Rules.winner/1`; `Rules.random_dice(n)`.
  - `LanParty.LiarsDice.View.player_view(game, token) :: %{dice: [1..6], roll: pos_integer, face: nil | 2..6, out?: boolean}`
  - `LanParty.LiarsDice.View.table_view(game) :: %{counts: [{token, non_neg_integer}] (seat order), total: non_neg_integer, face: nil | 2..6, roll: pos_integer}`

- [x] **Step 1: Write the failing tests**

`test/lan_party/liars_dice/rules_test.exs`:

```elixir
defmodule LanParty.LiarsDice.RulesTest do
  use ExUnit.Case, async: true

  alias LanParty.LiarsDice.Rules

  # A fixed "roll": the first n of these values. Five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp all_twos(n), do: List.duplicate(2, n)

  defp game, do: Rules.new(["a", "b", "c"], %{}, roller: &fixed/1)
  defp with_dice(game, dice), do: %{game | dice: Map.merge(game.dice, dice)}

  describe "new/3" do
    test "everyone gets 5 dice, sorted low to high; roll 1, no face, no winner" do
      game = game()

      assert game.players == ["a", "b", "c"]
      assert game.dice == %{"a" => [1, 1, 3, 4, 6], "b" => [1, 1, 3, 4, 6], "c" => [1, 1, 3, 4, 6]}
      assert game.roll == 1
      assert game.face == nil
      assert Rules.winner(game) == nil
    end

    test "settings are ignored, and the default roller rolls real dice" do
      game = Rules.new(["a", "b"], %{stack_plus2: true}, [])

      for {_token, dice} <- game.dice do
        assert length(dice) == 5
        assert dice == Enum.sort(dice)
        assert Enum.all?(dice, &(&1 in 1..6))
      end
    end

    test "random_dice/1 rolls n dice from 1 to 6" do
      assert Rules.random_dice(0) == []
      dice = Rules.random_dice(200)
      assert length(dice) == 200
      assert Enum.all?(dice, &(&1 in 1..6))
    end
  end

  describe "rolling" do
    test "players with dice re-roll as many as they have; out players stay out; the roll goes up; the face clears" do
      game = game() |> with_dice(%{"b" => [2, 5], "c" => []})
      game = %{game | face: 4, roller: &all_twos/1}

      assert {:ok, rolled} = Rules.table_action(game, :roll)
      assert rolled.dice == %{"a" => [2, 2, 2, 2, 2], "b" => [2, 2], "c" => []}
      assert rolled.roll == 2
      assert rolled.face == nil
    end
  end

  describe "counting" do
    test "the face can be 2 to 6" do
      for face <- 2..6 do
        assert {:ok, %{face: ^face}} = Rules.table_action(game(), {:count, face})
      end
    end

    test "1s are wild, so 1 can't be counted; nor can 7 or junk" do
      for face <- [1, 7, 0, "4", nil] do
        assert Rules.table_action(game(), {:count, face}) == {:error, :bad_face}
      end
    end
  end

  describe "taking a die" do
    test "the player loses their highest die; the others keep theirs" do
      assert {:ok, game} = Rules.table_action(game(), {:take_die, "a"})
      assert game.dice["a"] == [1, 1, 3, 4]
      assert game.dice["b"] == [1, 1, 3, 4, 6]
      assert Rules.winner(game) == nil
    end

    test "it changes neither the roll nor the face" do
      game = %{game() | face: 4}
      assert {:ok, %{face: 4, roll: 1}} = Rules.table_action(game, {:take_die, "a"})
    end

    test "taking the last die puts the player out, but keeps their seat" do
      game = game() |> with_dice(%{"a" => [3]})

      assert {:ok, game} = Rules.table_action(game, {:take_die, "a"})
      assert game.dice["a"] == []
      assert "a" in game.players
      assert Rules.winner(game) == nil
    end

    test "when only one player has dice left, they win" do
      game = game() |> with_dice(%{"a" => [3], "c" => []})

      assert {:ok, game} = Rules.table_action(game, {:take_die, "a"})
      assert Rules.winner(game) == "b"
    end

    test "unknown players and players with no dice are refused" do
      assert Rules.table_action(game(), {:take_die, "zed"}) == {:error, :not_in_game}

      game = game() |> with_dice(%{"c" => []})
      assert Rules.table_action(game, {:take_die, "c"}) == {:error, :no_dice}
    end
  end

  describe "remove_player/2" do
    test "a kicked player's dice leave the game" do
      game = Rules.remove_player(game(), "b")

      assert game.players == ["a", "c"]
      refute Map.has_key?(game.dice, "b")
      assert Rules.winner(game) == nil
    end

    test "if only one player with dice is left, they win" do
      game = game() |> with_dice(%{"c" => []}) |> Rules.remove_player("b")
      assert Rules.winner(game) == "a"
    end

    test "removing an out player doesn't end the game" do
      game = game() |> with_dice(%{"c" => []}) |> Rules.remove_player("c")

      assert game.players == ["a", "b"]
      assert Rules.winner(game) == nil
    end
  end

  test "phones have no moves" do
    assert Rules.apply_action(game(), "a", :roll) == {:error, :no_actions}
  end

  test "a table action Liar's Dice doesn't know is refused" do
    assert Rules.table_action(game(), {:draw_for, "a", 2}) == {:error, :unknown_action}
  end
end
```

`test/lan_party/liars_dice/view_test.exs`:

```elixir
defmodule LanParty.LiarsDice.ViewTest do
  use ExUnit.Case, async: true

  alias LanParty.LiarsDice.{Rules, View}

  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)

  defp game do
    game = Rules.new(["a", "b", "c"], %{}, roller: &fixed/1)
    %{game | dice: %{"a" => [2, 5], "b" => [1, 1, 3, 4, 6], "c" => []}, face: 4, roll: 3}
  end

  test "a phone sees only its own dice, the roll number and the face" do
    assert View.player_view(game(), "a") == %{dice: [2, 5], roll: 3, face: 4, out?: false}
  end

  test "a player with no dice is out" do
    assert View.player_view(game(), "c").out?
  end

  test "the table sees each player's dice count in seat order and the total, never a die's value" do
    assert View.table_view(game()) == %{counts: [{"a", 2}, {"b", 5}, {"c", 0}], total: 7, face: 4, roll: 3}
  end
end
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `mix test test/lan_party/liars_dice`
Expected: FAIL. `LanParty.LiarsDice.Rules` is undefined.

- [x] **Step 3: Implement**

`lib/lan_party/liars_dice/rules.ex`:

```elixir
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
    dice = Map.new(game.dice, fn {token, dice} -> {token, roll_dice(game.roller, length(dice))} end)
    {:ok, %{game | dice: dice, roll: game.roll + 1, face: nil}}
  end

  def table_action(%__MODULE__{} = game, {:count, face}) when face in 2..6, do: {:ok, %{game | face: face}}
  def table_action(%__MODULE__{}, {:count, _face}), do: {:error, :bad_face}

  def table_action(%__MODULE__{} = game, {:take_die, token}) do
    case Map.fetch(game.dice, token) do
      :error -> {:error, :not_in_game}
      {:ok, []} -> {:error, :no_dice}
      # The dice are sorted, so the last one is the highest.
      {:ok, dice} -> {:ok, check_winner(%{game | dice: Map.put(game.dice, token, Enum.drop(dice, -1))})}
    end
  end

  def table_action(%__MODULE__{}, _action), do: {:error, :unknown_action}

  @impl true
  def remove_player(%__MODULE__{} = game, token) do
    check_winner(%{game | players: List.delete(game.players, token), dice: Map.delete(game.dice, token)})
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
```

`lib/lan_party/liars_dice/view.ex`:

```elixir
defmodule LanParty.LiarsDice.View do
  @moduledoc """
  What each screen may see of a Liar's Dice game: a phone gets only its own dice; the table gets the
  counts and the total, never a die's value. See docs/liars-dice/design.md §4 "Views".
  """

  alias LanParty.LiarsDice.Rules

  def player_view(%Rules{} = game, token) do
    dice = Map.get(game.dice, token, [])
    %{dice: dice, roll: game.roll, face: game.face, out?: dice == []}
  end

  def table_view(%Rules{} = game) do
    counts = Enum.map(game.players, &{&1, length(Map.get(game.dice, &1, []))})
    %{counts: counts, total: counts |> Enum.map(&elem(&1, 1)) |> Enum.sum(), face: game.face, roll: game.roll}
  end
end
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `mix test test/lan_party/liars_dice`, then `mix test` and `mix compile --warnings-as-errors`.
Expected: PASS, no warnings.

- [x] **Step 5: Commit**

```powershell
mix format lib/lan_party/liars_dice/rules.ex lib/lan_party/liars_dice/view.ex test/lan_party/liars_dice/rules_test.exs test/lan_party/liars_dice/view_test.exs
git add lib/lan_party/liars_dice test/lan_party/liars_dice
git commit -m "feat: Liar's Dice rules and views" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3 (dice-b): dice components

**Files:**
- Create: `lib/lan_party_web/live/liars_dice/components.ex`
- Test: `test/lan_party_web/live/liars_dice/components_test.exs`

**Interfaces:**
- Produces:
  - `LanPartyWeb.LiarsDice.Components.face/1`: attrs `value` (1..6, required), `class` (default nil), plus global attrs (e.g. `style`). Renders `<span class="pips nV [class]"><i></i>×V</span>`.
  - `LanPartyWeb.LiarsDice.Components.die/1`: attrs `id` (default nil), `value` (required), `rolling` (boolean, default false), `state` (nil | "lit" | "dim"). Renders `<span id class="die vV [rolling] [state]" role="img" aria-label="V"><span class="cube" aria-hidden="true">` six faces with classes `s1`..`s6` `</span></span>`, matching `docs/mockups/redesign/liars-dice/phone/dice.html`.

- [x] **Step 1: Write the failing test**

`test/lan_party_web/live/liars_dice/components_test.exs`:

```elixir
defmodule LanPartyWeb.LiarsDice.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import LanPartyWeb.LiarsDice.Components

  defp pips(html), do: length(String.split(html, "<i></i>")) - 1

  test "a flat face has one pip per point" do
    for value <- 1..6 do
      assigns = %{value: value}
      html = rendered_to_string(~H"""
      <.face value={@value} />
      """)

      assert html =~ ~s(class="pips n#{value}")
      assert pips(html) == value
    end
  end

  test "a face passes extra attributes through" do
    assigns = %{}
    html = rendered_to_string(~H"""
    <.face value={5} style="--x:62%" />
    """)

    assert html =~ ~s(style="--x:62%")
  end

  test "a 3D die has all six sides and is labelled with its value" do
    assigns = %{}
    html = rendered_to_string(~H"""
    <.die id="die-1-0" value={3} />
    """)

    assert html =~ ~s(id="die-1-0")
    assert html =~ ~s(class="die v3")
    assert html =~ ~s(role="img")
    assert html =~ ~s(aria-label="3")
    assert html =~ ~s(class="cube" aria-hidden="true")
    for side <- 1..6, do: assert(html =~ ~s(class="pips n#{side} s#{side}"))
    assert pips(html) == 21
  end

  test "rolling plays the animation; a count lights a die up or dims it" do
    assigns = %{}

    assert rendered_to_string(~H"""
           <.die value={4} rolling />
           """) =~ ~s(class="die v4 rolling")

    assert rendered_to_string(~H"""
           <.die value={4} state="lit" />
           """) =~ ~s(class="die v4 lit")

    assert rendered_to_string(~H"""
           <.die value={2} rolling state="dim" />
           """) =~ ~s(class="die v2 rolling dim")
  end
end
```

- [x] **Step 2: Run the test to verify it fails**

Run: `mix test test/lan_party_web/live/liars_dice/components_test.exs`
Expected: FAIL. `LanPartyWeb.LiarsDice.Components` is undefined.

- [x] **Step 3: Implement**

`lib/lan_party_web/live/liars_dice/components.ex`:

```elixir
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
    <span id={@id} class={["die", "v#{@value}", @rolling && "rolling", @state]} role="img" aria-label={@value}>
      <span class="cube" aria-hidden="true">
        <.face :for={side <- 1..6} value={side} class={"s#{side}"} />
      </span>
    </span>
    """
  end
end
```

- [x] **Step 4: Run the tests to verify they pass**

Run: `mix test test/lan_party_web/live/liars_dice/components_test.exs`, then `mix test` and
`mix compile --warnings-as-errors`.
Expected: PASS, no warnings. If `rendered_to_string` puts different whitespace inside the class
attribute, fix the component, not the test: the class strings must be exactly as asserted, since the
LiveView tests in Tasks 5–6 select on them.

- [x] **Step 5: Commit**

```powershell
mix format lib/lan_party_web/live/liars_dice/components.ex test/lan_party_web/live/liars_dice/components_test.exs
git add lib/lan_party_web/live/liars_dice/components.ex test/lan_party_web/live/liars_dice/components_test.exs
git commit -m "feat: Liar's Dice dice components" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4 (dice-a): Liar's Dice is playable

Starts after the orchestrator has merged Tasks 1–3 into `liars-dice` and fast-forwarded `ld-a`.

**Files:**
- Modify: `lib/lan_party/games.ex`
- Test: `test/lan_party/games_test.exs`, create `test/lan_party/room_liars_dice_test.exs`

**Interfaces:**
- Consumes: Task 1's `Room.table_act/2` and `Games.module/1`; Task 2's `LiarsDice.Rules`.
- Produces: `Games.playable?(:liars_dice) == true`, `Games.module(:liars_dice) == LanParty.LiarsDice.Rules`.

- [x] **Step 1: Write the failing tests**

In `test/lan_party/games_test.exs`, rename the first test to
`"all 8 games from CLAUDE.md, in order; UNO and Liar's Dice are playable"`, add
`assert Games.playable?(:liars_dice)` after `assert Games.playable?(:uno)`, and in the `module` test add
`assert Games.module(:liars_dice) == LanParty.LiarsDice.Rules`.

`test/lan_party/room_liars_dice_test.exs`:

```elixir
defmodule LanParty.RoomLiarsDiceTest do
  use ExUnit.Case, async: true

  alias LanParty.Room
  alias LanParty.LiarsDice.Rules

  # Every roll: five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Alice, Bob and Carol in the Liar's Dice lobby.
  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    topic = Atom.to_string(name)
    start_supervised!({Room, name: name, topic: topic, grace_ms: 50, game_opts: [roller: &fixed/1]})
    Room.subscribe(topic)

    pages = Map.new(["t1", "t2", "t3"], &{&1, page()})
    :ok = Room.join(name, "t1", "Alice", pages["t1"])
    :ok = Room.join(name, "t2", "Bob", pages["t2"])
    :ok = Room.join(name, "t3", "Carol", pages["t3"])
    :ok = Room.pick_game(name, :liars_dice)
    %{room: name, pages: pages}
  end

  # Close a player's page and wait past the grace period, so they're kicked.
  defp kick(page) do
    Process.exit(page, :kill)
    Process.sleep(80)
  end

  defp set_dice(room, dice) do
    :sys.replace_state(room, fn state -> put_in(state.game.dice, Map.merge(state.game.dice, dice)) end)
  end

  test "Start game gives every seated player 5 dice", %{room: room} do
    assert Room.start_game(room) == :ok

    state = Room.get_state(room)
    assert state.phase == :playing
    assert %Rules{players: ["t1", "t2", "t3"], roll: 1, face: nil} = state.game
    assert state.game.dice["t2"] == [1, 1, 3, 4, 6]
  end

  test "table controls go to the Liar's Dice rules, and every page hears about them", %{room: room} do
    :ok = Room.start_game(room)

    assert Room.table_act(room, {:count, 4}) == :ok
    assert_receive {:party_updated, %{game: %Rules{face: 4}}}
    assert Room.table_act(room, :roll) == :ok
    assert_receive {:party_updated, %{game: %Rules{face: nil, roll: 2}}}
    assert Room.table_act(room, {:count, 1}) == {:error, :bad_face}
    assert Room.table_act(room, {:take_die, "t1"}) == :ok
    assert length(Room.get_state(room).game.dice["t1"]) == 4
  end

  test "phones have no moves", %{room: room} do
    :ok = Room.start_game(room)
    assert Room.act(room, "t1", :roll) == {:error, :no_actions}
  end

  test "table controls are refused outside a game", %{room: room} do
    assert Room.table_act(room, :roll) == {:error, :not_now}
  end

  test "taking the last die of the second-to-last player finishes the game", %{room: room} do
    :ok = Room.start_game(room)
    set_dice(room, %{"t1" => [2], "t3" => []})

    assert Room.table_act(room, {:take_die, "t1"}) == :ok
    state = Room.get_state(room)
    assert state.phase == :finished
    assert state.winner == "t2"
    assert Room.table_act(room, :roll) == {:error, :not_now}
  end

  test "a kick that leaves one player with dice finishes the game", %{room: room, pages: pages} do
    :ok = Room.start_game(room)
    set_dice(room, %{"t3" => []})
    kick(pages["t2"])

    state = Room.get_state(room)
    assert state.phase == :finished
    assert state.winner == "t1"
  end

  test "kicking an out player doesn't end the game", %{room: room, pages: pages} do
    :ok = Room.start_game(room)
    set_dice(room, %{"t3" => []})
    kick(pages["t3"])

    state = Room.get_state(room)
    assert state.phase == :playing
    assert state.game.players == ["t1", "t2"]
  end

  test "after Play again, the next game starts again from roll 1", %{room: room} do
    :ok = Room.start_game(room)
    :ok = Room.table_act(room, :roll)
    :ok = Room.back_to_lobby(room)
    :ok = Room.start_game(room)

    assert Room.get_state(room).game.roll == 1
  end
end
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `mix test test/lan_party/games_test.exs test/lan_party/room_liars_dice_test.exs`
Expected: FAIL. `pick_game(:liars_dice)` returns `{:error, :not_playable}`.

- [x] **Step 3: Implement**

In `lib/lan_party/games.ex`, change the Liar's Dice entry to:

```elixir
    %{id: :liars_dice, name: "Liar's Dice", playable?: true, module: LanParty.LiarsDice.Rules},
```

- [x] **Step 4: Run all the tests**

Run: `mix test` and `mix compile --warnings-as-errors`.
Expected: PASS. Note: `test/lan_party_web/live/table_live_test.exs` doesn't list Liar's Dice among the
spines, so it still passes even though the Liar's Dice spine is gone.

- [x] **Step 5: Commit**

```powershell
mix format test/lan_party/room_liars_dice_test.exs
git add lib/lan_party/games.ex test/lan_party/games_test.exs test/lan_party/room_liars_dice_test.exs
git commit -m "feat: Liar's Dice is playable" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5 (dice-a): Liar's Dice on the table, and its box on the shelf

**Files:**
- Create: `lib/lan_party_web/live/liars_dice/table_component.ex`
- Modify: `lib/lan_party_web/live/table_live.ex` (only the three edits in Step 3)
- Test: `test/lan_party_web/live/liars_dice_table_test.exs`

**Interfaces:**
- Consumes: `Room.table_act/1`, `Room.change_game/0`, `Room.start_game/0`, `Room.back_to_lobby/0`,
  `Room.seated/1`, `Room.queued/1`, `Room.name/2`, `Room.away?/1`; `LiarsDice.View.table_view/1`;
  `LiarsDice.Components.face/1`; `LobbyComponents.avatar/1` and `players_panel/1`.
- Produces: `LanPartyWeb.LiarsDice.TableComponent`, a LiveComponent with attr `room`. Its root is
  `<div id={@id} style="display: contents">`, and TableLive gives it `id="liars-dice-table"`.

Screens (copy and markup: `docs/mockups/redesign/liars-dice/table/*.html`):

| Phase | Shows |
|---|---|
| `:lobby` | `.tv-head`: `.wordmark` "Liar's Dice" and `button.btn.btn-quiet` "Change game". `div.lobby.solo` holding `<.players_panel>`. `.start-row`: "Start needs at least 2 players." under 2 seated players, otherwise "Everyone starts with 5 dice."; then `button.btn.btn-big` "Start game", disabled under 2. |
| `:playing` | `.tv-head`: wordmark and `button.btn.btn-quiet` "Reset". `.ring`: the top row of seats, `.felt.felt-dice` (total, face picker, Roll), the bottom row. `.tv-foot`: the queue ("Next game:" with avatars and names) and "Tap a player to take a die." (or the error). Plus the take-a-die and reset panels. |
| `:finished` | `.tv-head` with the wordmark only. `section.winner`: the winner's avatar, "Alice won", "Last one with dice", `button.btn.btn-big` "Play again", and the join note. |

- [x] **Step 1: Write the failing tests**

`test/lan_party_web/live/liars_dice_table_test.exs`:

```elixir
defmodule LanPartyWeb.LiarsDiceTableTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers, only: [sync: 1, restart_room: 0]

  alias LanParty.Room

  # Every roll: five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Erin is in the Liar's Dice lobby, and the table is open.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, fn state -> %{state | game_opts: [roller: &fixed/1]} end)
    :ok = Room.join("erin", "Erin", page())
    :ok = Room.pick_game(:liars_dice)
    {:ok, table, _html} = live(conn, ~p"/table")
    %{table: table}
  end

  defp join(table, token, name) do
    :ok = Room.join(token, name, page())
    sync(table)
  end

  defp start(table, others \\ [{"bob", "Bob"}]) do
    for {token, name} <- others, do: join(table, token, name)
    table |> element("button", "Start game") |> render_click()
  end

  # Change the Room behind the table's back, then let the table re-render.
  defp tweak_room(table, fun) do
    :sys.replace_state(Room, fun)
    send(table.pid, {:party_updated, Room.get_state()})
    sync(table)
  end

  defp set_dice(table, dice), do: tweak_room(table, fn state -> put_in(state.game.dice, Map.merge(state.game.dice, dice)) end)
  defp tap_seat(table, token), do: table |> element(~s(a.seat[phx-value-token="#{token}"])) |> render_click()
  defp component(table), do: with_target(table, "#liars-dice-table")

  describe "the lobby" do
    test "shows the players; Start needs 2", %{table: table} do
      assert has_element?(table, ".wordmark", "Liar's Dice")
      assert has_element?(table, ".lobby.solo", "Erin")
      assert has_element?(table, "button", "Change game")
      assert has_element?(table, "button[disabled]", "Start game")
      assert has_element?(table, ".start-row p", "Start needs at least 2 players.")

      join(table, "bob", "Bob")
      refute has_element?(table, "button[disabled]", "Start game")
      assert has_element?(table, ".start-row p", "Everyone starts with 5 dice.")
    end

    test "Change game goes back to Select the game", %{table: table} do
      table |> element("button", "Change game") |> render_click()
      assert has_element?(table, "h1", "Select the game")
    end
  end

  describe "the shelf" do
    setup %{table: table} do
      table |> element("button", "Change game") |> render_click()
      :ok
    end

    test "has a Liar's Dice box instead of its spine; tapping it picks Liar's Dice", %{table: table} do
      assert has_element?(table, ".box-dice .box-tag", "2 to 8 players")
      assert has_element?(table, ".box-dice .box-art .pips.n6")
      refute has_element?(table, ".spine b", "Liar's Dice")

      table |> element(".box-dice") |> render_click()
      assert Room.get_state().game_id == :liars_dice
      assert has_element?(table, ".wordmark", "Liar's Dice")
    end

    test "the side panel lists both games", %{table: table} do
      assert has_element?(table, ".shelf-aside p", "The classic card game.")
      assert has_element?(table, ".shelf-aside p", "Bluff about hidden dice.")

      table |> element(".shelf-aside button", "Play Liar's Dice") |> render_click()
      assert Room.get_state().game_id == :liars_dice
    end
  end

  describe "a game" do
    test "every seat has 5 dice; the total, the face picker and Roll; never a die's value", %{table: table} do
      start(table)

      assert has_element?(table, ".seat .name", "Erin")
      assert has_element?(table, ".seat .name", "Bob")
      assert has_element?(table, ".seat .count", "5")
      assert has_element?(table, ".dice-total b", "10")
      assert has_element?(table, ".dice-total", "dice in play")
      assert has_element?(table, ".face-pick p", ~s(Someone called "Liar!"? Pick the face that was bid.))

      for face <- 2..6 do
        assert has_element?(table, ~s(.face-btn[aria-label="Count #{face}s"][aria-pressed="false"]))
      end

      assert has_element?(table, "button.roll", "Roll")
      assert has_element?(table, "button", "Reset")
      assert has_element?(table, ".tv-foot", "Tap a player to take a die.")
      refute has_element?(table, ".die")
    end

    test "picking a face raises it; another face moves it; Roll clears it", %{table: table} do
      start(table)

      table |> element(~s(.face-btn[aria-label="Count 4s"])) |> render_click()
      assert Room.get_state().game.face == 4
      assert has_element?(table, ~s(.face-btn[aria-label="Count 4s"][aria-pressed="true"]))
      assert has_element?(table, ".face-pick p", "Counting 4s. 1s are wild. Count the phones out loud.")

      table |> element(~s(.face-btn[aria-label="Count 6s"])) |> render_click()
      assert has_element?(table, ~s(.face-btn[aria-label="Count 6s"][aria-pressed="true"]))
      refute has_element?(table, ~s(.face-btn[aria-label="Count 4s"][aria-pressed="true"]))

      table |> element("button.roll") |> render_click()
      assert Room.get_state().game.roll == 2
      refute has_element?(table, ~s(.face-btn[aria-pressed="true"]))
    end

    test "a junk face is ignored", %{table: table} do
      start(table)
      table |> component() |> render_click("count", %{"face" => "7"})
      table |> component() |> render_click("count", %{"face" => "x"})
      assert Room.get_state().game.face == nil
    end

    test "away players are tagged and their dice still count", %{table: table} do
      start(table)
      tweak_room(table, fn state -> put_in(state.people["bob"].pids, MapSet.new()) end)

      assert has_element?(table, ".seat.away .pill", "Away")
      assert has_element?(table, ".dice-total b", "10")
    end

    test "late joiners show in the footer", %{table: table} do
      start(table)
      join(table, "gus", "Gus")
      assert has_element?(table, ".tv-foot .next", "Gus")
    end
  end

  describe "taking a die" do
    test "tapping a player opens the panel; Cancel changes nothing", %{table: table} do
      start(table)
      tap_seat(table, "erin")

      assert has_element?(table, ".modal h2", "Take a die from Erin?")
      assert has_element?(table, ".modal p", "Erin goes from 5 dice to 4.")

      table |> element(".modal button", "Cancel") |> render_click()
      refute has_element?(table, ".modal")
      assert length(Room.get_state().game.dice["erin"]) == 5
    end

    test "Remove takes one die; a second tap takes nothing more", %{table: table} do
      start(table)
      tap_seat(table, "erin")
      table |> element(".modal button", "Remove") |> render_click()

      assert length(Room.get_state().game.dice["erin"]) == 4
      refute has_element?(table, ".modal")
      assert has_element?(table, ".dice-total b", "9")

      # A second "take" arriving after the panel closed is ignored.
      table |> component() |> render_click("take", %{})
      assert length(Room.get_state().game.dice["erin"]) == 4
    end

    test "a player's last die: the panel says they're out, and the seat lies flat", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")

      assert has_element?(table, ".modal h2", "Take Erin's last die?")
      assert has_element?(table, ".modal p", "Erin is out of the game.")

      table |> element(".modal button", "Remove") |> render_click()
      assert has_element?(table, ".seat.out .name", "Erin")
      assert has_element?(table, ".seat.out .pill", "Out")
      refute has_element?(table, ~s(a.seat[phx-value-token="erin"]))
    end

    test "an Out seat can't be tapped", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"carol" => []})

      refute has_element?(table, ~s(a.seat[phx-value-token="carol"]))
      table |> component() |> render_click("open_take", %{"token" => "carol"})
      table |> component() |> render_click("open_take", %{"token" => "nobody"})
      refute has_element?(table, ".modal")
    end

    test "when the last die ends the game, the panel says who wins; then the winner shows", %{table: table} do
      start(table)
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")
      assert has_element?(table, ".modal p", "Erin is out, and Bob wins.")

      table |> element(".modal button", "Remove") |> render_click()
      assert has_element?(table, ".winner h1", "Bob won")
      assert has_element?(table, ".winner .lead", "Last one with dice")
      assert has_element?(table, ".winner button", "Play again")
    end

    test "the panel closes when its player loses their last die at another table", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")

      :ok = Room.table_act({:take_die, "erin"})
      sync(table)
      refute has_element?(table, ".modal")
    end

    test "a take that fails says so", %{table: table} do
      start(table, [{"bob", "Bob"}, {"carol", "Carol"}])
      set_dice(table, %{"erin" => [3]})
      tap_seat(table, "erin")

      # Another table took it, and this table hasn't heard yet.
      :sys.replace_state(Room, fn state -> put_in(state.game.dice["erin"], []) end)
      table |> element(".modal button", "Remove") |> render_click()
      assert has_element?(table, ".tv-foot [role=alert]", "That didn't work. Try again.")
    end
  end

  describe "the end" do
    test "Reset asks first, then everyone goes back to the lobby", %{table: table} do
      start(table)
      table |> element("button", "Reset") |> render_click()

      assert has_element?(table, ".modal h2", "End this game?")
      assert has_element?(table, ".modal p", "Nobody wins, and everyone goes back to the lobby.")

      table |> element(".modal button", "End game") |> render_click()
      assert Room.get_state().phase == :lobby
      assert has_element?(table, "button", "Start game")
    end

    test "late joiners join at Play again", %{table: table} do
      start(table)
      join(table, "gus", "Gus")
      set_dice(table, %{"erin" => [3]})
      :ok = Room.table_act({:take_die, "erin"})
      sync(table)

      assert has_element?(table, ".winner .lobby-note", "Gus joins at Play again.")
      table |> element("button", "Play again") |> render_click()
      assert Room.seated(Room.get_state()) == ["erin", "bob", "gus"]
    end

    test "the result survives the winner leaving", %{table: table} do
      start(table)
      set_dice(table, %{"erin" => [3]})
      :ok = Room.table_act({:take_die, "erin"})
      tweak_room(table, fn state -> %{state | people: Map.delete(state.people, "bob"), order: List.delete(state.order, "bob")} end)

      assert has_element?(table, ".winner h1", "Someone won")
    end
  end
end
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `mix test test/lan_party_web/live/liars_dice_table_test.exs`
Expected: FAIL (the table renders nothing for Liar's Dice; no shelf box).

- [x] **Step 3: Implement**

`lib/lan_party_web/live/liars_dice/table_component.ex`:

```elixir
defmodule LanPartyWeb.LiarsDice.TableComponent do
  @moduledoc """
  Liar's Dice on the table: the lobby (Start, Change game), the game (seats with dice counts, the
  total, the face picker, Roll, take a die, Reset), and the winner. Rendered by `TableLive` once
  Liar's Dice is picked. Never shows a die's value (docs/liars-dice/README.md "Views").
  Markup follows docs/mockups/redesign/liars-dice/table/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.LiarsDice.Components
  import LanPartyWeb.LobbyComponents

  alias LanParty.Room
  alias LanParty.LiarsDice.View

  @impl true
  def update(%{id: id, room: room}, socket) do
    view = if room.game, do: View.table_view(room.game)
    {top_row, bottom_row} = rows(view)

    {:ok,
     socket
     |> assign(id: id, room: room, view: view, top_row: top_row, bottom_row: bottom_row)
     |> assign(seated: Room.seated(room), queued: Room.queued(room))
     |> assign_new(:take, fn -> nil end)
     |> assign_new(:confirm_reset, fn -> false end)
     |> assign_new(:error, fn -> nil end)
     |> close_stale_panels()}
  end

  ## Events

  @impl true
  def handle_event("change_game", _params, socket), do: reply(socket, Room.change_game())
  def handle_event("start", _params, socket), do: reply(socket, Room.start_game())
  def handle_event("roll", _params, socket), do: reply(socket, Room.table_act(:roll))

  def handle_event("count", %{"face" => face}, socket) do
    case Integer.parse(face) do
      {face, ""} when face in 2..6 -> reply(socket, Room.table_act({:count, face}))
      _junk -> {:noreply, socket}
    end
  end

  def handle_event("open_take", %{"token" => token}, socket) do
    if socket.assigns.room.phase == :playing and dice_count(socket.assigns.view, token) > 0,
      do: {:noreply, assign(socket, take: token)},
      else: {:noreply, socket}
  end

  # A second tap on Remove arrives after the panel closed: ignore it.
  def handle_event("take", _params, %{assigns: %{take: nil}} = socket), do: {:noreply, socket}

  def handle_event("take", _params, socket) do
    result = Room.table_act({:take_die, socket.assigns.take})
    reply(assign(socket, take: nil), result)
  end

  def handle_event("ask_reset", _params, socket), do: {:noreply, assign(socket, confirm_reset: true)}
  def handle_event("cancel", _params, socket), do: {:noreply, assign(socket, take: nil, confirm_reset: false)}

  def handle_event("back_to_lobby", _params, socket),
    do: reply(assign(socket, confirm_reset: false), Room.back_to_lobby())

  defp reply(socket, :ok), do: {:noreply, assign(socket, error: nil)}
  defp reply(socket, {:error, :not_enough_players}), do: {:noreply, assign(socket, error: "Start needs at least 2 players.")}
  defp reply(socket, {:error, _reason}), do: {:noreply, assign(socket, error: "That didn't work. Try again.")}

  ## What to show

  # Panels close outside a game. The take-a-die panel also closes when its player has no dice left
  # (another table took the last one) or has left the game.
  defp close_stale_panels(%{assigns: %{room: %{phase: :playing}, take: take, view: view}} = socket) do
    if take && dice_count(view, take) == 0, do: assign(socket, take: nil), else: socket
  end

  defp close_stale_panels(socket), do: assign(socket, take: nil, confirm_reset: false)

  defp dice_count(view, token), do: Enum.find_value(view.counts, 0, fn {t, count} -> t == token && count end)

  # Seats around the table: the first half along the top, the rest along the bottom, right to left.
  defp rows(nil), do: {[], []}

  defp rows(%{counts: counts}) do
    {top, bottom} = Enum.split(counts, div(length(counts) + 1, 2))
    {top, Enum.reverse(bottom)}
  end

  defp take_text(room, view, token) do
    name = Room.name(room, token)
    count = dice_count(view, token)
    others = for {other, n} <- view.counts, other != token, n > 0, do: other

    cond do
      count > 1 -> %{title: "Take a die from #{name}?", line: "#{name} goes from #{count} dice to #{count - 1}."}
      match?([_], others) -> %{title: "Take #{name}'s last die?", line: "#{name} is out, and #{Room.name(room, hd(others))} wins."}
      true -> %{title: "Take #{name}'s last die?", line: "#{name} is out of the game."}
    end
  end

  defp names(room, tokens), do: Enum.map(tokens, &Room.name(room, &1))

  defp join_note([one]), do: "#{one} joins at Play again."
  defp join_note(names), do: "#{Enum.join(Enum.drop(names, -1), ", ")} and #{List.last(names)} join at Play again."

  defp away?(room, token) do
    case room.people[token] do
      nil -> true
      person -> Room.away?(person)
    end
  end

  attr :token, :string, required: true
  attr :count, :integer, required: true
  attr :room, :map, required: true
  attr :target, :any, required: true

  # Out of the game: the seat lies flat and can't be tapped.
  defp seat(%{count: 0} = assigns) do
    ~H"""
    <div class="seat out">
      <.avatar room={@room} token={@token} />
      <span class="who">
        <span class="name">{Room.name(@room, @token)}</span>
        <span class="pill"><span class="dot coral"></span>Out</span>
      </span>
      <span class="count">0<small>dice</small></span>
    </div>
    """
  end

  defp seat(assigns) do
    ~H"""
    <a
      class={["seat", away?(@room, @token) && "away"]}
      phx-click="open_take"
      phx-value-token={@token}
      phx-target={@target}
    >
      <.avatar room={@room} token={@token} />
      <span class="who">
        <span class="name">{Room.name(@room, @token)}</span>
        <span :if={away?(@room, @token)} class="pill"><span class="dot sun"></span>Away</span>
      </span>
      <span class="count">{@count}<small>{if @count == 1, do: "die", else: "dice"}</small></span>
    </a>
    """
  end

  ## Render

  @impl true
  def render(assigns) do
    assigns = assign(assigns, take_text: assigns.take && take_text(assigns.room, assigns.view, assigns.take))

    ~H"""
    <div id={@id} style="display: contents">
      <%= case @room.phase do %>
        <% :lobby -> %>
          <header class="tv-head">
            <span class="wordmark">Liar's Dice</span>
            <button class="btn btn-quiet" phx-click="change_game" phx-target={@myself}>Change game</button>
          </header>
          <div class="lobby solo">
            <.players_panel room={@room} />
          </div>
          <div class="start-row">
            <p :if={length(@seated) < 2}>Start needs at least 2 players.</p>
            <p :if={length(@seated) >= 2}>Everyone starts with 5 dice.</p>
            <p :if={@error} role="alert">{@error}</p>
            <button class="btn btn-big" phx-click="start" phx-target={@myself} disabled={length(@seated) < 2}>
              Start game
            </button>
          </div>
        <% :playing -> %>
          <header class="tv-head">
            <span class="wordmark">Liar's Dice</span>
            <button class="btn btn-quiet" phx-click="ask_reset" phx-target={@myself}>Reset</button>
          </header>
          <div class="ring">
            <div class={["seats", length(@top_row) > 3 && "four"]}>
              <.seat :for={{token, count} <- @top_row} token={token} count={count} room={@room} target={@myself} />
            </div>
            <div class="felt felt-dice">
              <p class="dice-total"><b>{@view.total}</b><span>dice in play</span></p>
              <div class="face-pick" role="group" aria-label="Light up a face on every phone">
                <p :if={is_nil(@view.face)}>Someone called "Liar!"? Pick the face that was bid.</p>
                <p :if={@view.face}>Counting <b>{@view.face}s</b>. 1s are wild. Count the phones out loud.</p>
                <div class="face-row">
                  <a
                    :for={face <- 2..6}
                    class="face-btn"
                    role="button"
                    aria-label={"Count #{face}s"}
                    aria-pressed={to_string(@view.face == face)}
                    phx-click="count"
                    phx-value-face={face}
                    phx-target={@myself}
                  >
                    <.face value={face} />
                  </a>
                </div>
              </div>
              <button class="btn btn-big roll" phx-click="roll" phx-target={@myself}>Roll</button>
            </div>
            <div class={["seats", length(@bottom_row) > 3 && "four"]}>
              <.seat :for={{token, count} <- @bottom_row} token={token} count={count} room={@room} target={@myself} />
            </div>
          </div>
          <footer class="tv-foot">
            <span :if={@queued != []} class="next">
              Next game:
              <span class="faces" aria-hidden="true"><.avatar :for={token <- @queued} room={@room} token={token} /></span>
              <strong>{Enum.join(names(@room, @queued), ", ")}</strong>
            </span>
            <span :if={@queued == []}></span>
            <span :if={@error} role="alert">{@error}</span>
            <span :if={!@error}>Tap a player to take a die.</span>
          </footer>

          <div :if={@take_text} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">{@take_text.title}</h2>
              <p>{@take_text.line}</p>
              <div class="buttons">
                <button class="btn btn-quiet" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn" phx-click="take" phx-target={@myself}>Remove</button>
              </div>
            </div>
          </div>

          <div :if={@confirm_reset} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">End this game?</h2>
              <p>Nobody wins, and everyone goes back to the lobby.</p>
              <div class="buttons">
                <button class="btn btn-quiet" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn" phx-click="back_to_lobby" phx-target={@myself}>End game</button>
              </div>
            </div>
          </div>
        <% :finished -> %>
          <header class="tv-head"><span class="wordmark">Liar's Dice</span></header>
          <section class="winner">
            <.avatar :if={@room.people[@room.winner]} room={@room} token={@room.winner} />
            <h1>{Room.name(@room, @room.winner) || "Someone"} won</h1>
            <p class="lead">Last one with dice</p>
            <div class="buttons">
              <button class="btn btn-big" phx-click="back_to_lobby" phx-target={@myself}>Play again</button>
            </div>
            <p :if={@queued != []} class="lobby-note">{join_note(names(@room, @queued))}</p>
          </section>
      <% end %>
    </div>
    """
  end
end
```

`lib/lan_party_web/live/table_live.ex`: these three edits only.

1. Under the existing `import LanPartyWeb.Uno.Components`, add
   `alias LanPartyWeb.LiarsDice.Components, as: Dice`.
2. In the shelf, add the Liar's Dice box right after the UNO box's closing `</a>`, and replace the
   whole `<div class="shelf-aside">…</div>` with the two-game version (design.md §2, item 12; markup from
   `docs/mockups/platform/table/index.html`). The Play buttons are regular size, so plain `btn` with
   no `btn-big`. `app.css` already has the `.box-dice` rules and `.shelf-aside .btn + h2`.

```heex
            <a class="box-dice" phx-click="pick_game" phx-value-id="liars_dice" aria-label="Liar's Dice, 2 to 8 players">
              <span class="box-logo" aria-hidden="true">Liar's<br />Dice</span>
              <span class="box-art" aria-hidden="true">
                <Dice.face value={1} style="--x:-58%;--y:18%;--r:-14deg" />
                <Dice.face value={5} style="--x:62%;--y:24%;--r:11deg" />
                <Dice.face value={6} style="--x:0%;--y:-14%;--r:4deg" />
              </span>
              <span class="box-tag">2 to 8 players</span>
            </a>
```

```heex
            <div class="shelf-aside">
              <h2>UNO</h2>
              <p>The classic card game.</p>
              <button class="btn" phx-click="pick_game" phx-value-id="uno">Play UNO</button>
              <h2>Liar's Dice</h2>
              <p>Bluff about hidden dice.</p>
              <button class="btn" phx-click="pick_game" phx-value-id="liars_dice">Play Liar's Dice</button>
            </div>
```

3. After the UNO `<.live_component ... id="uno-table" ... />` block, add:

```heex
      <.live_component
        :if={@room.game_id == :liars_dice}
        module={LanPartyWeb.LiarsDice.TableComponent}
        id="liars-dice-table"
        room={@room}
      />
```

Don't change `main_class`: it's already `"tv"` for every picked game.

- [x] **Step 4: Run the tests**

Run: `mix test test/lan_party_web/live/liars_dice_table_test.exs`, then `mix test` and
`mix compile --warnings-as-errors`.
Expected: PASS. If a test fails because of `LobbyComponents` markup, report it to the orchestrator
instead of editing `lobby_components.ex`.

- [x] **Step 5: Commit**

```powershell
mix format lib/lan_party_web/live/liars_dice/table_component.ex test/lan_party_web/live/liars_dice_table_test.exs
git add lib/lan_party_web/live/liars_dice/table_component.ex lib/lan_party_web/live/table_live.ex test/lan_party_web/live/liars_dice_table_test.exs
git commit -m "feat: Liar's Dice on the table, and its box on the shelf" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6 (dice-b): Liar's Dice on the phone

**Files:**
- Create: `lib/lan_party_web/live/liars_dice/player_component.ex`
- Modify: `lib/lan_party_web/live/player_live.ex` and `lib/lan_party_web/live/lobby_components.ex`
  (only the edits in Step 3)
- Test: `test/lan_party_web/live/liars_dice_phone_test.exs`

**Interfaces:**
- Consumes: `LiarsDice.View.player_view/2`; `LiarsDice.Components.die/1`;
  `LobbyComponents.avatar/1`, `phone_lobby/1`, `phone_queue/1`; `Room.name/2`.
- Produces: `LanPartyWeb.LiarsDice.PlayerComponent`, a LiveComponent with attrs `room` and `token`.
  PlayerLive gives it `id="liars-dice-phone"`.

Screens (copy and markup: `docs/mockups/redesign/liars-dice/phone/*.html`; the header bar belongs to
PlayerLive):

| Screen | When | Shows |
|---|---|---|
| `:queue` | you're queued | `<.phone_queue>` |
| `:dice` | playing, you have dice | `section.stage` with, during a count, `p.counting` "Counting **4s**" and `p.stage-hint` "1s are wild. Show your phone."; `div.dice` with your dice; then, outside a count, `p.hint.dice-hint` "Bids are out loud. Keep your dice hidden." |
| `:out` | playing, no dice | `div.message`: "You're out." / `p.lead` "No dice left. Watch the rest of the game on the table." / `a.wait` "Waiting for the game to end" |
| `:finished`, you won | finished | `div.message.centered`: your dice (no animation), `h1.huge.win` "You won!", `a.wait` "Waiting for the table" |
| `:finished`, someone else won | finished | `div.message.centered`: the winner's avatar, `h1.huge` "Alice won", `p.lead` "Last one with dice", `a.wait` "Waiting for the table" |
| `:lobby` | otherwise | `<.phone_lobby>` |

**The roll animation** (design.md §5): each die's id is `die-<roll>-<index>`, so a new roll inserts new
elements and the CSS animation plays. The component remembers the roll it first saw (`seen_roll`) and
adds `rolling` only when `view.roll > seen_roll`. Outside a game `seen_roll` resets to 0, so the first
roll of the next game animates even on a phone that was opened mid-game.

- [x] **Step 1: Write the failing tests**

`test/lan_party_web/live/liars_dice_phone_test.exs`:

```elixir
defmodule LanPartyWeb.LiarsDicePhoneTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers, only: [sync: 1, restart_room: 0]

  alias LanParty.Room

  # Every roll: five dice sort to [1, 1, 3, 4, 6].
  defp fixed(n), do: Enum.take([6, 1, 4, 1, 3], n)
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)
  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})

  # Erin (this phone) and Bob, in the Liar's Dice lobby.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, fn state -> %{state | game_opts: [roller: &fixed/1]} end)
    {:ok, erin, _html} = live(phone(conn, "erin"), ~p"/")
    erin |> form("#join", %{name: "Erin"}) |> render_submit()
    :ok = Room.join("bob", "Bob", page())
    :ok = Room.pick_game(:liars_dice)
    sync(erin)
    %{erin: erin}
  end

  # Change the Room behind the phone's back, then let the phone re-render.
  defp tweak_room(view, fun) do
    :sys.replace_state(Room, fun)
    send(view.pid, {:party_updated, Room.get_state()})
    sync(view)
  end

  test "the phone follows the table to Liar's Dice and waits in the lobby", %{erin: erin} do
    assert render(erin) =~ "Waiting for the table to start"
  end

  test "Start game: your 5 dice, sorted, rolling in; no buttons", %{erin: erin} do
    :ok = Room.start_game()
    sync(erin)

    for {value, index} <- Enum.with_index([1, 1, 3, 4, 6]) do
      assert has_element?(erin, "#die-1-#{index}.die.v#{value}.rolling")
    end

    refute has_element?(erin, "#die-1-5")
    assert has_element?(erin, ".dice-hint", "Bids are out loud. Keep your dice hidden.")
    refute has_element?(erin, "button")
  end

  test "a phone shows only its own dice", %{erin: erin} do
    :ok = Room.start_game()
    tweak_room(erin, fn state -> put_in(state.game.dice["bob"], [2, 2, 2, 2, 2]) end)

    assert has_element?(erin, ".die.v1")
    refute has_element?(erin, ".die.v2")
  end

  test "a phone opened mid-game shows its dice already landed; the next roll animates", %{conn: conn} do
    :ok = Room.start_game()
    {:ok, again, _html} = live(phone(conn, "erin"), ~p"/")

    assert has_element?(again, "#die-1-0")
    refute has_element?(again, ".die.rolling")

    :ok = Room.table_act(:roll)
    sync(again)
    assert has_element?(again, "#die-2-0.rolling")
    refute has_element?(again, "#die-1-0")
  end

  test "a phone opened mid-game still animates the first roll of the next game", %{conn: conn} do
    :ok = Room.start_game()
    :ok = Room.table_act(:roll)
    {:ok, again, _html} = live(phone(conn, "erin"), ~p"/")

    :ok = Room.back_to_lobby()
    sync(again)
    :ok = Room.start_game()
    sync(again)
    assert has_element?(again, "#die-1-0.rolling")
  end

  test "a count lights up the face and the 1s and dims the rest; Roll clears it", %{erin: erin} do
    :ok = Room.start_game()
    :ok = Room.table_act({:count, 4})
    sync(erin)

    assert has_element?(erin, ".counting", "Counting 4s")
    assert has_element?(erin, ".stage-hint", "1s are wild. Show your phone.")
    assert has_element?(erin, "#die-1-0.v1.lit")
    assert has_element?(erin, "#die-1-1.v1.lit")
    assert has_element?(erin, "#die-1-2.v3.dim")
    assert has_element?(erin, "#die-1-3.v4.lit")
    assert has_element?(erin, "#die-1-4.v6.dim")
    refute has_element?(erin, ".dice-hint")

    :ok = Room.table_act(:roll)
    sync(erin)
    refute has_element?(erin, ".die.lit")
    refute has_element?(erin, ".die.dim")
    refute has_element?(erin, ".counting")
  end

  test "when the table takes a die, the highest goes and the rest stay put", %{erin: erin} do
    :ok = Room.start_game()
    :ok = Room.table_act({:take_die, "erin"})
    sync(erin)

    assert has_element?(erin, "#die-1-3.v4")
    refute has_element?(erin, "#die-1-4")
  end

  test "with no dice left, you're out", %{erin: erin} do
    :ok = Room.join("carol", "Carol", page())
    :ok = Room.start_game()
    for _ <- 1..5, do: :ok = Room.table_act({:take_die, "erin"})
    sync(erin)

    assert has_element?(erin, ".message h1", "You're out.")
    assert has_element?(erin, ".message .lead", "No dice left. Watch the rest of the game on the table.")
    assert has_element?(erin, ".message .wait", "Waiting for the game to end")
  end

  test "the last one with dice wins; the others see who", %{erin: erin, conn: conn} do
    {:ok, bob, _html} = live(phone(conn, "bob"), ~p"/")
    :ok = Room.start_game()
    for _ <- 1..5, do: :ok = Room.table_act({:take_die, "bob"})
    sync(erin)
    sync(bob)

    assert has_element?(erin, ".message h1.win", "You won!")
    assert has_element?(erin, ".message .dice .die.v6")
    refute has_element?(erin, ".message .die.rolling")
    assert has_element?(erin, ".message .wait", "Waiting for the table")

    assert has_element?(bob, ".message h1", "Erin won")
    assert has_element?(bob, ".message .lead", "Last one with dice")
  end

  test "the result survives the winner leaving", %{erin: erin} do
    :ok = Room.start_game()
    for _ <- 1..5, do: :ok = Room.table_act({:take_die, "erin"})
    sync(erin)
    assert has_element?(erin, ".message h1", "Bob won")

    tweak_room(erin, fn state -> %{state | people: Map.delete(state.people, "bob"), order: List.delete(state.order, "bob")} end)
    assert has_element?(erin, ".message h1", "Someone won")
  end

  test "a late joiner waits in the queue for this game to end", %{conn: conn} do
    :ok = Room.start_game()
    {:ok, gus, _html} = live(phone(conn, "gus"), ~p"/")
    gus |> form("#join", %{name: "Gus"}) |> render_submit()

    assert has_element?(gus, ".message h1", "You're #1 in line.")
    assert has_element?(gus, ".message .wait", "Waiting for this game to end")
  end
end
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `mix test test/lan_party_web/live/liars_dice_phone_test.exs`
Expected: FAIL (the phone renders nothing for Liar's Dice).

- [x] **Step 3: Implement**

`lib/lan_party_web/live/liars_dice/player_component.ex`:

```elixir
defmodule LanPartyWeb.LiarsDice.PlayerComponent do
  @moduledoc """
  Liar's Dice on a phone: lobby, queue, your dice (the roll animation and the count highlight), out,
  and the result. No buttons: the phone is a dice cup. Rendered by `PlayerLive` once the table picks
  Liar's Dice. Shows only this player's dice (docs/liars-dice/README.md "Views").
  Markup follows docs/mockups/redesign/liars-dice/phone/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.LiarsDice.Components
  import LanPartyWeb.LobbyComponents

  alias LanParty.Room
  alias LanParty.LiarsDice.View

  @impl true
  def update(%{id: id, room: room, token: token}, socket) do
    in_game? = not is_nil(room.game) and token in room.game.players
    view = if in_game?, do: View.player_view(room.game, token)

    {:ok,
     socket
     |> assign(id: id, room: room, token: token, view: view)
     |> assign(screen: screen(room, room.people[token], view))
     |> assign_seen_roll(room, view)}
  end

  ## What to show

  defp screen(_room, %{status: :queued}, _view), do: :queue
  defp screen(%{phase: :playing}, _me, %{out?: true}), do: :out
  defp screen(%{phase: :playing}, _me, %{}), do: :dice
  defp screen(%{phase: :finished}, _me, %{}), do: :finished
  defp screen(_room, _me, _view), do: :lobby

  # The roll animation plays only for rolls that happen while this page is open (design.md §5): remember
  # the roll this page first saw and animate only later ones. Outside a game it resets, so the first roll
  # of the next game animates.
  defp assign_seen_roll(socket, %{phase: :playing}, %{roll: roll}), do: assign_new(socket, :seen_roll, fn -> roll end)
  defp assign_seen_roll(socket, _room, _view), do: assign(socket, seen_roll: 0)

  # During a count, the dice showing the face, or a wild 1, light up; the rest dim.
  defp count_state(_value, nil), do: nil
  defp count_state(value, face) when value == face or value == 1, do: "lit"
  defp count_state(_value, _face), do: "dim"

  ## Render

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} style="display: contents">
      <.phone_lobby :if={@screen == :lobby} room={@room} token={@token} />
      <.phone_queue :if={@screen == :queue} room={@room} token={@token} />

      <%= if @screen == :dice do %>
        <section class="stage" aria-label="Your dice">
          <p :if={@view.face} class="counting">Counting <b>{@view.face}s</b></p>
          <p :if={@view.face} class="stage-hint">1s are wild. Show your phone.</p>
          <div class="dice">
            <.die
              :for={{value, index} <- Enum.with_index(@view.dice)}
              id={"die-#{@view.roll}-#{index}"}
              value={value}
              rolling={@view.roll > @seen_roll}
              state={count_state(value, @view.face)}
            />
          </div>
        </section>
        <p :if={is_nil(@view.face)} class="hint dice-hint">Bids are out loud. Keep your dice hidden.</p>
      <% end %>

      <div :if={@screen == :out} class="message">
        <h1>You're out.</h1>
        <p class="lead">No dice left. Watch the rest of the game on the table.</p>
        <a class="wait">Waiting for the game to end</a>
      </div>

      <div :if={@screen == :finished and @room.winner == @token} class="message centered">
        <div class="dice"><.die :for={value <- @view.dice} value={value} /></div>
        <h1 class="huge win">You won!</h1>
        <a class="wait">Waiting for the table</a>
      </div>

      <div :if={@screen == :finished and @room.winner != @token} class="message centered">
        <.avatar :if={@room.people[@room.winner]} room={@room} token={@room.winner} />
        <h1 class="huge">{Room.name(@room, @room.winner) || "Someone"} won</h1>
        <p class="lead">Last one with dice</p>
        <a class="wait">Waiting for the table</a>
      </div>
    </div>
    """
  end
end
```

`lib/lan_party_web/live/player_live.ex`: this one edit only. After the UNO
`<.live_component ... id="uno-phone" ... />` block, add:

```heex
      <.live_component
        :if={@me && @room.game_id == :liars_dice}
        module={LanPartyWeb.LiarsDice.PlayerComponent}
        id="liars-dice-phone"
        room={@room}
        token={@token}
      />
```

The header bar already shows the avatar, "Playing as …" and the wordmark `Games.name(room.game_id)`
("Liar's Dice"). Leave it alone; the UNO session owns it.

`lib/lan_party_web/live/lobby_components.ex`, in `phone_queue/1` (agreed with the UNO session; design.md §2,
item 11: a Liar's Dice game has many rounds, so "game" fits both games): change
`Waiting for this round to end` to `Waiting for this game to end`. Nothing else in that file.
Then run `grep -rn "this round to end" test lib`; if a UNO test asserts the old text, update that one
string.

- [x] **Step 4: Run the tests**

Run: `mix test test/lan_party_web/live/liars_dice_phone_test.exs`, then `mix test` and
`mix compile --warnings-as-errors`.
Expected: PASS. If a test fails because of `LobbyComponents` markup, report it to the orchestrator
instead of changing `lobby_components.ex` beyond the wording.

- [x] **Step 5: Commit**

```powershell
mix format lib/lan_party_web/live/liars_dice/player_component.ex test/lan_party_web/live/liars_dice_phone_test.exs
git add lib/lan_party_web/live/liars_dice/player_component.ex lib/lan_party_web/live/player_live.ex lib/lan_party_web/live/lobby_components.ex test/lan_party_web/live/liars_dice_phone_test.exs
git commit -m "feat: Liar's Dice on the phone" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7 (orchestrator): check, document, hand over

- [x] **Step 1:** If `main` has moved on (the UNO session keeps working there), merge it into
  `liars-dice` and resolve conflicts in `player_live.ex` / `table_live.ex` by keeping both sides.
- [x] **Step 2:** `mix test`, `mix compile --warnings-as-errors`.
- [x] **Step 3:** Visual check: run the server and compare each Liar's Dice screen with
  `docs/mockups/redesign/liars-dice/` (headless screenshots at phone and TV sizes). Send any CSS fix to
  the UNO session.
- [x] **Step 4:** Docs: `docs/liars-dice/README.md` and `design.md` status, `CLAUDE.md` status and the
  Games table. Tick this plan's boxes.
- [ ] **Step 5:** Ask the user before merging `liars-dice` into `main`.
