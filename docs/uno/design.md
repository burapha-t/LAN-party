# UNO, first build: design spec

- **Date:** 2026-10-12
- **Status:** Approved 2026-10-12. Revised and re-approved the same day for the game picker (one player
  URL for the night; the table picks the game) and the Reset confirmation. No code until the
  implementation plan is approved.
- **Mockups:** `docs/mockups/` (static HTML) shows every screen in §2. Build the screens to match them.
- **Inputs:** `CLAUDE.md` (platform) and `docs/uno/README.md` (UNO rules and product decisions). Both are
  part of this spec by reference. This file doesn't repeat the rules; it says how the product behaves
  and how it's built.

## 1. Goal and scope

Build the LAN Party server with UNO as its only game, meeting the success criteria in `CLAUDE.md`:
one command to start, phones join with nothing installed, a full round can be played to a winner with
a TV or iPad as the table, a sleeping phone keeps its seat, and every rule is enforced by the server.

**In scope:** the rules in `docs/uno/README.md`, the phone view, the table view, joining once per night,
the game picker (UNO is the only playable game), the queue, disconnects and kicks, and the startup log.

**Out of scope:** animations, sounds, drag-and-drop, an "UNO" button, chat, scores across rounds,
spectators, more than one game running at a time, accounts, HTTPS, keeping state across a server
restart, playing the other planned games (the picker lists them as not built yet).

## 2. Product: what people see and do

### The night: one URL each

- **Players** open `/` all night. **Table devices** open `/table`. Games have no URLs of their own.
- The table picks the game; every phone switches to it on its own.

### Phone (`/`)

| Situation | What the phone shows |
|---|---|
| Not joined | Name field + **Join**. A taken name shows "That name is taken". Joining is once per night. |
| Came back after being kicked | The join screen, plus "You were away too long and left the game. Join again for the next game.", with their old name already filled in. |
| Joined, no game picked yet | "Waiting for the table to pick a game". |
| In the UNO lobby | "You're in. Waiting for the table to start", and the list of players. |
| In the queue | "Game in progress. You're #2 in line." |
| Playing | Whose turn it is and your hand, sorted by color, then number. **No pile and no current color**: players look at the table screen for those. Cards are **not** highlighted; spotting a match is up to you. A **Draw** button. |
| Your turn | "Your turn" with the hint "Match the top card on the table." |
| A draw penalty is aimed at you | "+4 coming at you" (or +2, +6, ...) and "Dave played it.", with **Draw N**, **Challenge** when allowed, and a hint like "Or tap a +4 in your hand to stack it." when stacking is allowed. |
| You tapped a Wild | A color picker (4 colors + Cancel). The play is sent only after you pick. |
| You tapped a 7 (7-0 on) | A player picker. The play is sent only after you pick. |
| You drew a playable card | **Play it** / **Keep it**. |
| The first card flipped was a Wild and you go first | A color picker to choose the starting color. |
| An illegal move | A short message, e.g. "Not your turn", "Doesn't match: red 7", "Resolve the +4 first". |
| Round over | "You won!" or "Alice won". Stays until the table taps **Play again**, then back to the lobby screen. |
| Phone loses connection | Phoenix's built-in "reconnecting" state. It comes back on its own. |

### Table (`/table`)

| Phase | What the table shows |
|---|---|
| Select the game | "Select the game": all 8 games from `CLAUDE.md`. UNO can be picked; the other 7 are greyed out and marked "Not built yet". Also lists who has joined. |
| UNO lobby | Joined players, the queue, the four house-rule switches, **Start** (disabled with fewer than 2 players), **Change game** (back to "Select the game"). |
| Playing | Top card and current color, draw pile size, direction of play, every player with their card count, the current player highlighted, an *away* tag on disconnected players, any pending draw total (e.g. "+6"), and the queue ("Next game: Dave, Erin"). Tap a player to open the draw-for panel ("Make Alice draw [−] 2 [+]", **Cancel** / **Draw**). **Reset** button, which asks first: "End this round?" / "Nobody wins, and everyone goes back to the lobby." with **Cancel** / **End round**. |
| Finished | The winner and **Play again**. |

Every open table device shows the same thing, and any of them can use the controls.

### Product details decided during design

These follow from the decisions in the README but weren't discussed one by one. Flag any you disagree
with.

1. **Every draw penalty needs a tap from its target**, even a plain +2 with stacking off ("+2 coming at
   you", **Accept (draw 2)**). This gives others a moment to jump in, and makes the +2 and +4 flows look
   the same.
2. **With jump-in on, the target of a +2 can escape with an identical +2**, even with stacking off. It
   counts as a jump-in, and "anyone can jump in" includes the target. The total moves to the next player.
3. **Winning ends the round at once.** If your last card is a 7, 0, +2 or +4, its effect isn't applied.
4. **Starting card is Reverse:** the direction flips, and the randomly chosen first player still goes
   first.
5. **Draw for player doesn't affect play at all.** It doesn't change the turn, and it doesn't close a
   jump-in window.
6. **If the player who played a +4 is kicked** before the challenge is resolved, the Challenge option
   disappears. The target can still accept or stack.
7. **More than 8 people:** seats go in arrival order. At "Play again", seated players keep their seats,
   and queued players fill any free seats in arrival order. Picking a game (including picking UNO
   again after Change game) re-seats everyone in arrival order, up to 8; the rest are queued. A seat
   freed in the lobby (someone was kicked) goes straight to the first person in the queue.
8. **If both piles run out** while drawing, the player draws as many as there are and the rest are
   skipped.
9. **Change game only from the lobby.** During a round the table shows Reset, not Change game, so no
   round is cut off. House-rule settings are kept if UNO is picked again later that night.

## 3. Architecture

**Approach A** (chosen): pure rules code, wrapped by one long-running process that holds the platform
state.

```
phones (/)                   Room (GenServer)                tables (/table)
 PlayerLive ──action──▶  names · picked game · seats  ◀──action── TableLive (TV)
 PlayerLive ◀────────────── PubSub broadcast ───────────────▶ TableLive (iPad)
   └ Uno.PlayerComponent         │ plain function calls        └ Uno.TableComponent
                                 ▼
                         Uno.Rules (pure)
```

- `Uno.Rules`: pure functions over a game struct. No processes, no timers. All UNO rules live here.
- `Room`: one GenServer for the night. Names, the picked game, seats, queue, settings, phases,
  disconnects, grace timers, kicks. It doesn't track turns or cards.
- `Games`: the fixed list of the 8 games for the picker (`id`, name, playable or not). Just data.
- Two LiveViews, one per role: `PlayerLive` at `/` (join, "waiting for a game") and `TableLive` at
  `/table` ("Select the game"). Once UNO is picked, each renders a UNO **LiveComponent**
  (`Uno.PlayerComponent`, `Uno.TableComponent`) that draws the UNO screens and handles UNO taps. This
  keeps UNO code out of the platform views, and a second game would add its own two components.

**Why:** the standard Elixir shape, a pure core with a thin process around it. Requests are handled one
at a time in arrival order, so "first jump-in wins" needs no extra code, and the rules are testable
without a browser.
**Considered:** a separate lobby process plus a game process per round (needs coordination between the
two to keep arrival order), and an umbrella project with one app per game (too much structure before a
second game exists).

### Code layout

A standard Phoenix project at the repo root, created with `mix phx.new . --app lan_party --no-ecto`.

```
lib/lan_party/application.ex             # starts PubSub, Room, Endpoint; prints the URLs
lib/lan_party/lan_address.ex             # finds the LAN addresses for the startup log
lib/lan_party/games.ex                   # the 8 games for the picker; only :uno playable
lib/lan_party/room.ex                    # platform state for the night; no card logic
lib/lan_party/uno/card.ex                # card struct
lib/lan_party/uno/deck.ex                # the 108-card deck, shuffling
lib/lan_party/uno/rules.ex               # every UNO rule
lib/lan_party/uno/view.ex                # what a phone / the table may see of a game
lib/lan_party_web/plugs/player_token.ex  # gives each browser its token
lib/lan_party_web/live/player_live.ex    # `/`: join, waiting for a game, hosts the game component
lib/lan_party_web/live/table_live.ex     # `/table`: Select the game, hosts the game component
lib/lan_party_web/live/uno/components.ex        # card, color buttons
lib/lan_party_web/live/uno/player_component.ex  # UNO phone screens
lib/lan_party_web/live/uno/table_component.ex   # UNO table screens
test/lan_party/uno/*_test.exs
test/lan_party/room_test.exs
test/lan_party_web/live/*_test.exs
docs/                                    # docs/uno/ (rules, this spec, plan) and docs/mockups/
```

## 4. Identity, reconnect, kicks

- A plug gives each browser a random **player token** in Phoenix's signed session cookie, valid for one
  day. The token is the player's identity. "Reconnecting" means a page comes back with a token the Room
  already knows.
- Phone LiveViews call `Room.attach(token, pid)` once connected (not during the first static render).
  The Room monitors each page process. A token can have several pages open; the player is **away** only
  when the last one closes.
- When a player goes away, the Room starts a grace timer (30 s, set in config). Each timer carries a
  unique ref, so an old timer can't kick a player who came back.
  - Back in time → timer cancelled; seat and hand kept.
  - Timer fires → the token is forgotten and the seat freed. If a round is running, the Room calls
    `Uno.Rules.remove_player`. The token goes into `kicked` with the player's name, so the phone can show
    the "away too long" message and fill in the name; it's removed when they join again. In the lobby,
    the freed seat goes to the first person in the queue.
- Same rule while waiting for a game, in the lobby, in the queue, and during a round. If it's an away
  player's turn, the game waits. A kicked player is forgotten for the night and joins again with a name.
- Table devices have no identity and no grace period.

## 5. Room

### State

```elixir
%{
  game_id:  nil | :uno,     # the game the table picked; nil = "Select the game"
  phase:    :picking | :lobby | :playing | :finished,   # :picking exactly when game_id is nil
  people:   %{token => %{name, status: :seated | :queued, pids, away_ref}},
  order:    [token],        # arrival order; seated tokens in this order give the turn order
  monitors: %{ref => {token, pid}},
  kicked:   %{token => name},  # kicked since they last joined; the name is offered back on the join screen
  settings: map,            # UNO house rules, from Uno.Rules.default_settings/0; kept all night
  game:     nil | %Uno.Rules{},
  winner:   nil | token
}
```

While `:picking`, `status` has no meaning yet; picking a game sets it for everyone.

### API

All functions are `GenServer.call`, handled one at a time in arrival order.

| Caller | Function | Effect |
|---|---|---|
| Phone | `join(token, name, pid)` | Name trimmed, 1–20 characters, unique ignoring case. Seated if the phase is `:picking`, or `:lobby` with fewer than 8 seated; otherwise queued. |
| Phone | `attach(token, pid)` | Monitor the page; cancel any grace timer. |
| Phone | `act(token, action)` | `:playing` only. Calls `Uno.Rules.apply_action/3`. |
| Table | `pick_game(game_id)` | `:picking` only, playable games only. Sets `game_id`, phase `:lobby`; everyone is re-seated in arrival order, up to 8, the rest queued. |
| Table | `change_game()` | `:lobby` only. Back to `:picking`, `game_id` nil. |
| Table | `update_settings(settings)` | `:lobby` only. |
| Table | `start_game()` | `:lobby` with 2+ seated. Calls `Uno.Rules.new/2` and switches to `:playing`. |
| Table | `draw_for(token, n)` | `:playing` only, n from 1 to 10 (the panel's limits). Calls `Uno.Rules.draw_for/3`. |
| Table | `back_to_lobby()` | Used by both **Play again** and **Reset**. `:playing` or `:finished` only. Back to `:lobby`; `game` and `winner` cleared; queued players fill free seats in arrival order. |
| Both | `get_state()` | Used once on mount. |

- Errors (`{:error, reason}`) go back to the caller only.
- After every change, the Room broadcasts `{:party_updated, state}` on the PubSub topic `"party"`.
- After each `act`, if `Uno.Rules.winner/1` returns a token, the phase becomes `:finished`.
- **Last player left wins** is a Room rule. After a kick, if one seated player remains in `:playing`,
  the phase becomes `:finished` with that player as the winner.
- Functions the Room calls on `Uno.Rules`: `default_settings/0`, `new/2`, `apply_action/3`,
  `draw_for/3`, `remove_player/2`, `winner/1`. These become the shared interface (a behaviour) when a
  second game arrives.

## 6. UNO rules engine (`Uno.Rules`)

### Cards and deck

- `%Card{id, color, value}`. `id` is 1–108 and unique, so a phone can say which of two identical cards
  it played. `color` is `:red | :yellow | :green | :blue`, or `nil` for Wild and +4. `value` is `0..9`,
  `:skip`, `:reverse`, `:draw2`, `:wild` or `:wild_draw4`.
- Official deck: per color one 0, two each of 1–9, two Skip, two Reverse, two +2; plus 4 Wild and 4 +4.

### Game state

```elixir
%Uno.Rules{
  players:      [token],            # turn order
  hands:        %{token => [Card]},
  draw_pile:    [Card],
  discard:      [Card],             # head is the top card
  color:        color,              # current color (set by a Wild)
  current:      token,              # whose turn
  direction:    1 | -1,
  settings:     map,
  jump_in_open: boolean,            # false at the start; true after a play; false after a
                                    # player draws (draw_for doesn't count)
  pending:      nil
              | {:start_color, token}           # first card was a Wild
              | {:drawn, token, card_id}        # drew a playable card: play it or keep it
              | {:penalty, %{total: n, top: :draw2 | :draw4,
                             challenge: nil | %{by: token, legal: boolean}}},
  winner:       nil | token
}
```

A penalty always targets `current`.

### Actions (from phones)

| Action | Meaning |
|---|---|
| `{:play, card_id, opts}` | `opts` has `color` for Wild and +4, `swap_with` for a 7 under 7-0. |
| `:draw` | Draw one card on your turn. |
| `:keep` | Keep the card you just drew. |
| `:accept` | Take the pending penalty. |
| `:challenge` | Challenge the pending +4. |
| `{:choose_color, color}` | Set the starting color when the first card was a Wild. |

### Rules the engine applies

- **Matching:** a card is playable on your turn if it matches the current color or the top card's
  value, or it's a Wild or +4.
- **+4 legality:** recorded when played: legal only if the player held no card of the current color.
  Wilds don't count as the color.
- **Effects:** Skip skips the next player; Reverse flips direction (acts as Skip with 2 players);
  +2 and +4 create or grow a penalty for the next player; Wild sets the color; under 7-0, a 7 swaps
  hands with `swap_with` and a 0 passes every hand one seat in the direction of play.
- **Draw:** `:draw` gives one card. Playable → `{:drawn, ...}` pending, then play that card or `:keep`.
  Not playable → the turn passes. You can't `:draw` while a penalty is pending.
- **Penalty:** the target may `:accept` (draw the total, lose the turn), `:challenge` if allowed, or
  stack:

  | Top of the penalty | Card played | Allowed when |
  |---|---|---|
  | +2 | any +2 | Stacking +2s on |
  | +2 | +4 | both stacking switches on |
  | +4 | +4 | Stacking +4s on |
  | +4 | +2 of the chosen color | both stacking switches on |

- **Challenge:** only on a +4 that started a penalty (not one played onto a stack). Illegal +4 → the
  player who played it draws 4, the penalty is cleared, and the challenger takes their turn. Legal →
  the challenger draws 6 and loses the turn. Stacking on a +4 gives up the challenge.
- **Jump-in** (when on): while `jump_in_open`, anyone, including the current player or the penalty
  target, may play a card with the same color and value as the top card. Wild and +4 can't be jumped in
  on. Play continues from the jumper. A +2 jumped onto a pending +2 adds to the total, and the target
  becomes the player after the jumper.
- **Start:** a random first player. Flip the first card; a +4 goes to the bottom of the draw pile and
  the next card is flipped (the same as reshuffling an already shuffled deck, and testable).
  Skip, Reverse and +2 apply to the first player (see §2, "Product details" for Reverse). A Wild →
  `{:start_color, first}`. Number cards have no starting effect, even a 7 or 0 under 7-0.
- **Empty draw pile:** the discard pile minus its top card is shuffled into a new draw pile.
- **`remove_player/2`:** the player's cards are shuffled into the draw pile. If it was their turn, the
  turn passes. A penalty aimed at them is dropped. If they played the pending +4, the challenge is
  removed.
- **`draw_for/3`:** the player draws n cards. Nothing else changes.
- **Winning:** a play that empties a hand sets `winner` immediately; that card's effect isn't applied.

### Views

- `player_view(game, token)`: the hand (sorted), whose turn it is, the prompt for this player (if any),
  and the top card (used only to word error messages such as "Doesn't match: red 7"; the phone never
  draws the pile).
- `table_view(game)`: top card, color, draw pile size, direction, every player's card count, whose turn
  it is, and the pending total.

The UNO components render only these (they live in `Uno.View`). The full state reaches the LiveView
process on the server, but only the rendered HTML goes to the browser, so another player's hand never
leaves the server.

## 7. Startup and networking

- `mix phx.server` in dev mode is the one command.
- The endpoint binds to `{0, 0, 0, 0}` on port 4000.
- The WebSocket origin check must accept the LAN IP. The generated dev config already turns it off;
  keep it that way.
- On boot the log prints every private IPv4 address with its adapter name, since Windows often has
  extra adapters (e.g. WSL):

  ```
  LAN Party is running.
    Players: http://192.168.1.23:4000/  (Wi-Fi)
    Table:   http://192.168.1.23:4000/table
  ```

- Routes: `live "/", PlayerLive` and `live "/table", TableLive`. The generated `get "/"` page route is
  removed.

- On the first run, Windows asks whether to let `erl.exe` through the firewall. The host must allow
  **Private networks**. The README will say so.
- The mockups' font (Rubik) loads from Google Fonts. On a Wi-Fi without internet the pages fall back to
  the system font; the game works the same. Accepted by the user (2026-10-12).

## 8. Errors and failures

- **Illegal action:** `{:error, reason}` to the caller; the phone shows a short message. The table
  shows errors on its own controls only.
- **Room crash:** the supervisor restarts it empty. LiveViews monitor the Room and reload when it goes
  down (phones to `/`, tables to `/table`), so phones land on the join screen, tables on "Select the
  game", and the round is lost. Accepted: the Room is small and the
  rules are the most tested part.
- **Bad input** (unknown card id, a card you don't hold, an invalid color): rejected like any illegal
  move.

## 9. Testing

- **Rules unit tests** (the bulk): `Uno.Rules.new/3` takes options for a fixed deck and first player
  (`new/2` is `new/3` with no options), so every scenario is deterministic. One test per rule in the README and per "Product detail" in §2.
- **Room tests:** join, name taken, picking and changing the game (re-seating), queue, the 8-seat cap,
  back to lobby, grace timer and kick (the grace period is set to a few milliseconds in the test
  config), last player wins.
- **LiveView tests:** join flow, waiting for a game, phones switching to UNO when the table picks it,
  unbuilt games can't be picked, a phone renders only its own hand, table controls call the Room.
- **Manual party test:** the server on the laptop, 2+ phones and a tablet on the same Wi-Fi. Play a full
  round, lock a phone for 10 s and unlock it, and lock one for 40 s to see the kick.
