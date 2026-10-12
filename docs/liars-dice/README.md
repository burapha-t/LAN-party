# Liar's Dice — context

The second game on the LAN Party platform. Read the root `CLAUDE.md` first for the platform rules
(roles, lobby/queue, disconnects, max players). This file covers only what is specific to Liar's Dice.

- **How to get here:** Liar's Dice has no URL of its own. Players stay on `/`; the table opens `/table`
  and picks Liar's Dice from "Select the game", and every phone switches to it on its own.
- **Status:** Built 2026-10-12 from `plan.md` (spec: `design.md`), styled on the redesign mockups in
  `docs/mockups/redesign/liars-dice/`. Not yet tried on real devices.

## Rule mode: free-form

The phones replace the dice and cups, and the table keeps count. Everything else happens out loud, like
at a real table. The server rolls the dice, keeps each player's dice count, and decides who is out and
who won. It doesn't know about bids, turns, or who called "Liar!", and it never judges a challenge.
**Why:** the user wants the game as close to playing by hand as possible. The bluffing and the arguing
are the fun.

## Rules (as played at this table)

- 2–8 players (the platform caps it at 8). Everyone starts with **5 dice**.
- **Rolling:** the table's **Roll** button rolls every player's dice at once. Each player sees only
  their own dice, on their phone.
- **Bidding** goes around the table out loud, e.g. "four 5s" means "at least four dice on the whole
  table show a 5". Each bid must beat the last one. Players police this; the server doesn't track bids,
  turns, or who goes first.
- **1s are wild:** they count as whatever face was bid. Bids name a face from 2 to 6.
- **"Liar!":** a player calls the last bid a lie. Everyone turns their phone around, the table lights
  up the bid's face on every phone, and everyone counts out loud.
- **Losing a challenge costs one die.** The players decide who lost (the bidder if there were fewer
  dice than the bid, otherwise the caller), and someone at the table takes a die from that player.
- **Out:** a player with no dice left is out of the game.
- **Winning:** the last player with dice wins. **One game lasts until one player has dice left.** There
  are no points and no match.

## Views

**Phone (player, private)**
- Joining happens once per night on the platform's join screen at `/`, not inside Liar's Dice.
- Only your own dice, big, sorted from low to high. Nothing else about the game.
- A **rolling animation** every time the table rolls: the dice drop in, tumble and land.
- During a count, the dice that match (the picked face, plus 1s) light up and the rest dim, with the
  label "Counting 4s" and "1s are wild. Show your phone."
- No buttons. The phone is a dice cup: everything is done by talking, or on the table.

**Middle device (table, shared)**
- Every player's name and **dice count**, an *away* tag on disconnected players, and **Out** on players
  with no dice.
- The **total number of dice in play**, big, in the middle.
- Controls: **Roll**, the **face picker** (2 to 6), **take a die** from a player, **Reset**, and
  **Change game** in the lobby (back to "Select the game").
- The table never shows anyone's dice, and never says how many dice match a count.

## Roll (table control)

- Rolls every player who still has dice. Every phone plays the animation at the same moment.
- Clears any count highlight.
- **Start game** rolls the first round on its own, so the table doesn't tap Roll at the start.

## The count (table control)

- After "Liar!", someone taps the face that was bid: **2 3 4 5 6** (drawn as dice faces).
- On every phone, the dice showing that face or a 1 light up, and the rest dim. Players count them out
  loud with the phones turned around.
- **Why:** counting dice across 6–8 phones is slow and error-prone. Lighting the matches up makes it
  quick, but the number is still counted out loud, which keeps the suspense.
- Tapping another face moves the highlight. The next Roll clears it.

## Take a die (table control)

- Tap a player → a panel: "Take a die from Alice?" / "Alice goes from 3 dice to 2." with **Cancel /
  Remove**. For a player's last die: "Take Dave's last die?" / "Dave is out of the game."
- **Why:** there's no undo. A stray tap only opens the panel, so the panel is the confirm step (same as
  UNO's "draw for player").
- It removes one die from that player's current roll; their other dice don't change until the next
  Roll.

## Kicked players (Liar's Dice specifics)

The platform rule (grace period, then kick) applies. In Liar's Dice:
- The kicked player's dice leave the game, and the total drops.
- If only one player has dice left, that player wins (the platform's "last player left wins").
- An away player's dice still count, and are rolled with everyone else's.

## Ending the game

- When only one player has dice left, the game ends at once.
- The table shows the winner and a **Play again** button; phones show "You won!" or "Alice won".
  Queued players join at Play again.

## Open questions (Liar's Dice)

None right now. All were answered on 2026-10-12.
