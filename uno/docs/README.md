# UNO — context

The first game on the LAN Party platform. Read the root `CLAUDE.md` first for the platform rules
(roles, lobby/queue, disconnects, max players). This file covers only what is specific to UNO.

- **How to get here:** UNO has no URL of its own. Players stay on `/`; the table opens `/table` and
  picks UNO from "Select the game", and every phone switches to UNO on its own (see `CLAUDE.md`).
- **Status:** Design spec written in `design.md`, waiting for review. No code yet.

## Rule mode: enforced

The server checks every move and rejects illegal ones. The phone shows why a play was rejected.
**Why:** if players could make mistakes, we'd also need a way to take a played card back. Enforcing the
rules avoids building that.

## Rules

- **Base:** official UNO rules.
- **Optional house rules,** toggled on the middle device before the game starts. All off by default.
  - Stacking +2s
  - Stacking +4s
  - 7-0 rule (play a 7 → swap hands with a chosen player; play a 0 → everyone passes their hand in the
    direction of play)
  - Jump-in (play an identical card out of turn; play continues from that player)
- Player count: 2–8 (the platform caps it at 8). A game needs at least 2 players to start.
- **One game = one round.** The first player to empty their hand wins. No points, no match to 500.
  **Why:** rounds take a few minutes, so late joiners never wait long, and no scoreboard is needed.

### Setup (official)

- A random player goes first.
- First card flipped: if it's a +4, it's reflipped. Any other action card applies to the first player
  (e.g. a Wild lets the first player choose the color).

### Drawing (official)

- On your turn you may draw instead of playing, even if you have a playable card.
- You draw **one** card. If it's playable, your phone offers "Play it / Keep it". If not, the turn
  passes automatically.
- When the draw pile runs out, the discard pile (except its top card) is shuffled into a new draw pile.

### Two players (official)

- Reverse acts as Skip.

### Wild Draw Four challenge (official)

- A +4 can always be played, so bluffing is possible. It's legal only if the player held no card of the
  current color.
- The next player's phone asks **Challenge / Accept** (plus **Stack** when stacking allows it).
  - Challenge, +4 was illegal → the player who played it draws 4. The challenger draws nothing.
  - Challenge, +4 was legal → the challenger draws 6.
  - Accept → draw 4 as usual.
- The server knows every hand, so it settles the challenge instantly.

### Stacking (house rules)

- The two toggles work separately:
  - Only **Stacking +2s** on → +2 on +2.
  - Only **Stacking +4s** on → +4 on +4.
  - Both on → **any on any**: +4 on +2, and +2 on +4 if the +2 matches the color chosen for the +4.
- The first player who can't (or won't) stack draws the whole total.
- **No challenge inside a stack.** A +4 that starts a stack can be challenged as usual, and stacking on
  it gives up the challenge. A +4 played onto an existing stack can't be challenged.
  **Why:** inside a stack only draw cards are playable, so the official "no card of the current color"
  test would call a +4 a bluff when the player had no real alternative.

### 7-0 (house rule)

- Playing a 7 means you must choose a player to swap hands with.

### Jump-in (house rule)

- "Identical" means the same color and the same number or symbol. You can't jump in on a Wild or a +4,
  because they have no printed color.
- Anyone can jump in, including the player who just played (doubling up), until the next play or draw.
- If two jump-ins arrive at the same time, the server takes the first one it receives.
- The card takes effect from the jumper: a Skip skips the player after the jumper, a 7 makes the jumper
  swap, and so on. Play continues from the jumper.
- **Jumping in on a +2 adds up the penalty.** Bob plays a red +2 at Carol, and before Carol draws, Alice
  jumps in with a red +2. Carol is spared, and the player after Alice faces +4 (or stacks, if stacking
  is on). This applies even with stacking off.

## Views

**Phone (player, private)**
- Joining happens once per night on the platform's join screen at `/`, not inside UNO.
- Own hand, sorted by color, then number.
- Whose turn it is. When it's yours: "Your turn" with the hint "Match the top card on the table."
- **No pile and no current color on the phone** (decided 2026-10-12). Everyone looks at the table
  screen for the top card, like at a real table. The phone names the top card only in error messages,
  e.g. "Doesn't match: red 7".
- Playable cards are **not** highlighted. Spotting a match is up to the player, like at a real table;
  the server still rejects mistakes.
- Actions: play a card, draw a card. Plus prompts the rules need: Wild color, "Play it / Keep it" after
  a draw, Challenge / Accept / Stack on a +4, who to swap with on a 7.

**Middle device (table, shared)**
- Discard pile (top card) and draw pile.
- Whose turn it is.
- **Every player's card count** (public, like seeing the cards in someone's hand at a real table).
- Controls: house-rule settings before the game, start/reset, **draw for player** (see below), and
  **Change game** in the lobby (back to "Select the game").

## Calling "UNO!": social, not a button

- There is **no "UNO" button** on the phones. A button would give it away and ruin the fun.
- Card counts are public on the middle device, so other players watch them and call out anyone who
  forgets to say "UNO".
- The penalty is applied by hand: whoever holds the middle-device controller uses **draw for player**
  to give the caught player 2 cards.
- The server doesn't track whether "UNO" was said, or the timing window for catching someone. People
  judge that, like at a real table.

## Draw for player (middle-device control)

- The middle device can make any player draw cards from the draw pile.
- It's a referee override in an otherwise enforced game. It covers the UNO penalty and any other
  situation the rules engine doesn't model.
- Flow: tap a player → a panel opens: "Make Alice draw [−] 2 [+]" with **Cancel / Draw**. The amount
  defaults to 2 (the UNO penalty) and can be changed.
  **Why:** there's no undo. A stray tap only opens the panel, so the panel doubles as the confirm step.
- It does not change whose turn it is.

## Kicked players (UNO specifics)

The platform rule (grace period, then kick) applies. In UNO:
- The kicked player's cards are shuffled into the draw pile.
- If a draw penalty was waiting for them, it's dropped rather than passed to the next player, who did
  nothing to earn it.

## Ending the game

- A player who empties their hand wins.
- If every other player has been kicked, the last player left wins (platform rule).
- The middle device shows the winner and a **Play again** button. Queued players join at that point.

## Open questions (UNO)

None right now. All were answered on 2026-10-12.
