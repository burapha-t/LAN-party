# Liar's Dice: design spec

- **Date:** 2026-10-12
- **Status:** Written 2026-10-12. The user started implementation the same day, which approved it.
  Built from `plan.md`. The screens follow the redesign mockups (`docs/mockups/redesign/liars-dice/`), which
  replace the original mockups and the CSS notes below (§2 item 13, §3 "CSS").
- **Mockups:** `docs/mockups/` (static HTML) shows every screen in §2: the files in
  `liars-dice/phone/` and `liars-dice/table/`, plus the updated game shelf `platform/table/index.html`. Build the screens to match them.
- **Inputs:** `CLAUDE.md` (platform), `docs/liars-dice/README.md` (rules and product decisions) and
  `docs/uno/design.md` (the platform architecture this builds on). All are part of this spec by
  reference. This file doesn't repeat them; it says how Liar's Dice behaves and what changes to build
  it.

## 1. Goal and scope

Make Liar's Dice the second playable game: phones replace the dice and cups, and the table keeps the
count. **Done means:** the table picks Liar's Dice, 2–8 phones get 5 dice each with a rolling animation,
the group plays a full game to a winner using only Roll, the face picker and "take a die" on the table,
and a phone that sleeps for less than the grace period comes back with the same dice.

**In scope:** the rules in the README, the phone and table screens, the roll animation, the face
highlight, taking a die, kicks and the winner, the Liar's Dice box on the game shelf, and the platform
changes a second game needs (§3).

**Out of scope:** tracking bids, turns or who called "Liar!"; judging a challenge; undo; settings (the
starting dice count is fixed at 5); "spot on" and other variants; sounds; shaking the phone to roll;
showing anyone's dice on the table.

## 2. Product: what people see and do

### Phone (`/`)

| Situation | What the phone shows |
|---|---|
| In the Liar's Dice lobby | The shared lobby screen (same as UNO's): "You're in. Waiting for the table to start", and the players. |
| In the queue | The shared queue screen (same as UNO's): "You're #2 in line." |
| Playing | Only your dice, big, sorted low to high, under the header "Playing as Erin · Liar's Dice". Below: "Bids are out loud. Keep your dice hidden." No buttons. Mockup: `liars-dice/phone/dice.html` (reload it to replay the roll). |
| The table rolls | Every die drops in, tumbles and lands on its new face (about a second). |
| The table picks a face (a count) | "Counting **4s**" and "1s are wild. Show your phone." Dice showing a 4 or a 1 light up; the rest dim. Mockup: `liars-dice/phone/count.html`. |
| The table took one of your dice | The row shows one die fewer. |
| You're out (0 dice) | "You're out." / "No dice left. Watch the rest of the game on the table." Mockup: `liars-dice/phone/out.html`. |
| Game over | "You won!" with your last dice, or "Alice won" / "Last one with dice". Stays until the table taps **Play again**. Mockups: `liars-dice/phone/won.html`, `liars-dice/phone/lost.html`. |
| Phone loses connection | Phoenix's built-in "reconnecting" state, as in UNO. |

### Table (`/table`)

| Phase | What the table shows |
|---|---|
| Select the game | The shelf now has a **Liar's Dice box** next to UNO's, in place of its "Not built yet" spine. Tapping a box selects it (it grows and lights up); the side panel's **Play** button picks it (changed 2026-10-12, see CLAUDE.md "Decisions"). Mockup: `platform/table/index.html`. |
| Liar's Dice lobby | Joined players, the queue, "Everyone starts with 5 dice.", **Start game** (disabled with fewer than 2 players), **Change game**. No house rules. Mockup: `liars-dice/table/lobby.html`. |
| Playing | Every player with their dice count ("4 dice", "1 die"); *away* tag on disconnected players; players with no dice greyed out and tagged **Out**. In the middle: the total ("15 dice in play"), the face picker (2 to 6, drawn as dice faces) with "Someone called "Liar!"? Pick the face that was bid.", and **Roll**. Footer: the queue ("Next game: Gus, Hana") and "Tap a player to take a die." **Reset** in the header. Mockup: `liars-dice/table/playing.html`. |
| Counting | The picked face is raised and outlined; the line reads "Counting **4s**. 1s are wild. Count the phones out loud." No number. Mockup: `liars-dice/table/count.html`. |
| Take a die | Tap a player with dice: "Take a die from Alice?" / "Alice goes from 3 dice to 2." with **Cancel** / **Remove**. Last die: "Take Dave's last die?" / "Dave is out of the game." Mockups: `table/liars-dice-take-*.html`. |
| Reset | "End this game?" / "Nobody wins, and everyone goes back to the lobby." with **Cancel** / **End game**. Mockup: `liars-dice/table/reset.html`. |
| Finished | "Alice won", "Last one with dice", **Play again**, and who joins at Play again. Mockup: `liars-dice/table/finished.html`. |

Every open table device shows the same thing, and any of them can use the controls. In the mockups, the
total links to the finished screen, the way "Carol's turn" does in UNO's.

### Product details decided during design

These follow from the decisions in the README but weren't discussed one by one. Flag any you disagree
with.

1. **Start game rolls the first round.** Nobody has to tap Roll at the start.
2. **Dice are sorted low to high** on the phone, like UNO's sorted hand. It makes your own dice quicker
   to read, and a count quicker to check.
3. **The animation plays only for a roll that happens while the page is open.** Opening the page, or a
   phone waking up after a lock, shows the dice already landed, so it never looks like a re-roll.
4. **Roll and the face picker work any time during a game,** not only after "Liar!". A disputed round
   can be re-rolled, and a stray face tap only lights up dice on each player's own phone.
5. **The highlight stays until the next Roll.** Tapping another face moves it. Taking a die doesn't
   clear it.
6. **Taking a die removes the last one in the row** (the highest). The other dice keep their faces until
   the next Roll.
7. **If taking a die ends the game, the panel says so:** "Dave is out, and Alice wins."
8. **The game ends at once** when one player has dice left. There's no extra confirmation beyond the
   take-a-die panel.
9. **Out players keep their seat on the table,** greyed out and tagged Out, and can't be tapped. Their
   phone shows "You're out." until the game ends.
10. **Away players' dice still count** in the total and are rolled with everyone else's.
11. **The shared queue screen says "Waiting for this game to end"** (UNO's said "round"). A Liar's Dice
    game has many rounds; in UNO a game is one round, so the new wording fits both.
12. **The game shelf:** the side panel shows the selected game with a one-line description ("The
    classic card game.", "Bluff about hidden dice.") and a regular-size **Play** button, or "Tap a game
    to choose it." when nothing is selected. Below 1400 px wide (iPads, laptops) there's no room for it
    next to two boxes, so it sits above the shelf. (Changed 2026-10-12: it used to list both games, and
    tapping a box picked the game at once.)
13. **Colors:** Liar's Dice screens glow dark red (`glow-dice`, the box's color) during a game and at
    the end. The lit dice use UNO's yellow, and each die's 1 pip is red, which makes the wild 1s easy to
    spot.

## 3. Architecture: what changes for a second game

The UNO spec's shape stays: one Room process for the platform, a pure rules module per game, and one
pair of LiveComponents per game. The UNO spec said the Room's calls into `Uno.Rules` "become the shared
interface (a behaviour) when a second game arrives". This is that change. Nothing more general than
this is built.

```
PlayerLive ─┬─ Uno.PlayerComponent        Room ──▶ Games.module(game_id)
            └─ LiarsDice.PlayerComponent        ├─ Uno.Rules        (@behaviour LanParty.Game)
TableLive  ─┬─ Uno.TableComponent               └─ LiarsDice.Rules  (@behaviour LanParty.Game)
            └─ LiarsDice.TableComponent
```

### Platform changes

- **`LanParty.Game` behaviour.** The functions the Room calls on a game:

  | Callback | Meaning |
  |---|---|
  | `new(players, settings, opts)` | A new game for these seated tokens. `opts` is the Room's `game_opts` (tests use it to fix the deck or the dice). |
  | `apply_action(game, token, action)` | A phone's move. `{:ok, game}` or `{:error, reason}`. |
  | `table_action(game, action)` | A table control during a game. Same return shape. |
  | `remove_player(game, token)` | A kicked player leaves the game. |
  | `winner(game)` | `nil` or the winning token. |

  Every game struct has a `players` list of tokens; the Room's "one seated player left" check reads it.
- **`Games`:** playable entries get a `module` (`:uno` → `LanParty.Uno.Rules`, `:liars_dice` →
  `LanParty.LiarsDice.Rules`), plus `Games.module/1`. `:liars_dice` becomes playable.
- **`Room`:**
  - `act/2` (phones) and a new `table_act/1` (table controls) forward to the picked game's module.
  - UNO's "draw for player" moves behind it: `Room.draw_for` is removed, and the UNO table component
    calls `Room.table_act({:draw_for, token, n})`. `Uno.Rules.table_action/2` checks `n in 1..10`.
  - After every change to a game (phone action, table action, kick), the Room asks the module's
    `winner/1`; a winner switches the phase to `:finished`. The "one seated player left" rule stays.
  - `settings` stays UNO's house rules, kept all night, and Liar's Dice ignores it. Settings become per
    game only when a second game has settings of its own.
- **Web:**
  - `PlayerLive` and `TableLive` render the component for the picked game and take the glow / page class
    from it. `TableLive` renders the Liar's Dice box and side-panel entry on the shelf, and drops
    Liar's Dice from its spine list.
  - The phone lobby and queue screens, and the table lobby's player list with the seat and queue notes,
    are the same in both games. Move them out of the UNO components into function components in
    `LanPartyWeb.LobbyComponents`, and use them from both games instead of copying them.
- **CSS:** the new styles are in `docs/mockups/style.css` (sections "Liar's Dice" and the game shelf).
  `assets/css/app.css` is a copy of that file; copy it again.

### Code layout (new and changed files)

```
lib/lan_party/game.ex                         # new: the behaviour above
lib/lan_party/games.ex                        # changed: module per playable game; Liar's Dice playable
lib/lan_party/room.ex                         # changed: forwards to Games.module/1; table_act/1; winner check
lib/lan_party/uno/rules.ex                    # changed: @behaviour, table_action/2 wraps draw_for/3
lib/lan_party/liars_dice/rules.ex             # new: every Liar's Dice rule (§4)
lib/lan_party/liars_dice/view.ex              # new: what a phone / the table may see
lib/lan_party_web/live/lobby_components.ex    # new: shared lobby and queue screens
lib/lan_party_web/live/player_live.ex         # changed: picks the game's component
lib/lan_party_web/live/table_live.ex          # changed: picks the game's component; shelf box
lib/lan_party_web/live/uno/*.ex               # changed: shared lobby components; table_act for draw-for
lib/lan_party_web/live/liars_dice/components.ex        # new: die (3D) and flat face
lib/lan_party_web/live/liars_dice/player_component.ex  # new: Liar's Dice phone screens
lib/lan_party_web/live/liars_dice/table_component.ex   # new: Liar's Dice table screens
assets/css/app.css                            # changed: copied from docs/mockups/style.css
test/lan_party/liars_dice/rules_test.exs, view_test.exs
test/lan_party_web/live/liars_dice_phone_test.exs, liars_dice_table_test.exs
```

## 4. Liar's Dice rules engine (`LiarsDice.Rules`)

### Game state

```elixir
%LiarsDice.Rules{
  players: [token],           # seat order (arrival order), including players who are out
  dice:    %{token => [1..6]},# each list sorted low to high; [] = out
  roll:    pos_integer,       # 1 at the start, +1 on every roll; the phones animate when it goes up
  face:    nil | 2..6,        # the face being counted; nil = no highlight
  winner:  nil | token,
  roller:  (n -> [1..6])      # rolls n dice; :rand by default, fixed in tests via opts[:roller]
}
```

### Table actions

| Action | Effect | Errors |
|---|---|---|
| `:roll` | Every player with dice gets new dice (same count, sorted). `roll` + 1, `face` nil. | none |
| `{:count, face}` | `face` set. | `:bad_face` unless `face` is 2–6 |
| `{:take_die, token}` | That player loses the last (highest) die. If exactly one player has dice left, they're the `winner`. | `:not_in_game`, `:no_dice` |

### Other functions

- **`new/3`:** every player gets 5 rolled dice; `roll` 1, `face` nil. Settings are ignored.
- **`apply_action/3`:** phones have no actions in Liar's Dice; always `{:error, :no_actions}`.
- **`remove_player/2`:** the player leaves `players` and `dice`. If exactly one player has dice left,
  they're the `winner`.
- **`winner/1`:** returns `winner`.

During a game at least two players have dice, since the game ends as soon as only one does. So a kick
always leaves at least one player with dice, and there's always a winner.

### Views (`LiarsDice.View`)

- `player_view(game, token)`: your dice, `roll`, `face`, and whether you're out.
- `table_view(game)`: every player's dice count, the total, `face`, and `roll`. Never a die's value.

As in UNO, the components render only these. Only the rendered HTML reaches the browser, so nobody's
dice leave the server except to their own phone.

## 5. The roll animation

- **Pure CSS, no JS hook.** Each die is a 3D cube with six pip faces (`.die` / `.cube` in the
  stylesheet). Its value class (`v1`–`v6`) turns that face to the front. The `rolling` class plays two
  animations (about 1.1 s, slightly staggered per die): the die drops in and bounces, while the cube
  tumbles a few turns and lands on its value.
- **When it plays:** each die's DOM id includes the roll number (`die-<roll>-<index>`). A new roll gives
  new ids, so LiveView inserts fresh elements and the animation starts. A highlight change or a taken
  die keeps the ids, so nothing replays.
- **Not on page open:** the phone component remembers the roll number it first saw, and adds `rolling`
  only for later rolls (product detail 3).
- **Reduced motion:** the stylesheet's existing `prefers-reduced-motion` rule turns it off; the dice just
  appear.

## 6. Errors and failures

- **Table control errors** go back to that table device only, as in UNO. The screens hide the controls
  that would fail (an Out seat can't be tapped), so in practice they come from two tables tapping at
  once, e.g. both taking someone's last die: the second tap gets "That didn't work. Try again."
- **Room crash:** the same as UNO: the game is lost, phones go back to the join screen, tables to
  "Select the game".

## 7. Testing

- **Rules unit tests** (`new/3` with a fixed `roller`, so every roll is known):
  - `new`: 5 sorted dice each, `roll` 1, no face.
  - Roll: players with dice re-roll with the same count, out players stay out, `roll` + 1, face cleared.
  - Count: 2–6 accepted; 1, 7 and junk rejected.
  - Take a die: one fewer (the highest), out at 0, winner when one player has dice left, errors for an
    unknown token and for a player with no dice.
  - Remove a player: their dice leave; winner when one player has dice left.
  - Phone actions are always rejected.
- **View tests:** a phone sees only its own dice; the table view has counts, total and face, and no die
  values.
- **Room tests:** picking Liar's Dice, starting it, `table_act` forwarding, a winner moves the phase to
  `:finished`, a kick that leaves one player with dice finishes the game, phone actions rejected.
  UNO's draw-for Room tests move to `table_act({:draw_for, ...})`.
- **LiveView tests:** phones switch to Liar's Dice when the table picks it; a phone renders only its own
  dice; lit and dim classes after a count; the table's total and seat counts; the take-a-die panel
  (cancel, remove, last die, game-ending text); an Out seat isn't tappable; Play again.
- **Manual:** compare the screens with the mockups in a browser. Party test: a full game to a winner with
  3+ phones and a tablet; watch the roll animation on an iPhone (Safari) and an Android phone (Chrome);
  lock a phone mid-game and unlock it (same dice, no animation).
