# Undercover — context

The third game on the LAN Party platform. Read the root `CLAUDE.md` first for the platform rules
(roles, lobby/queue, disconnects, max players). This file covers only what is specific to Undercover.

- **How to get here:** like every game, no URL of its own. The table picks Undercover from "Select the
  game", and every phone switches to it.
- **Branch only:** Undercover lives on the local `undercover` branch, not `main`, because its word list
  has 18+ pairs. Don't merge or push it.
- **Status:** Decided and built 2026-10-13 (decided in chat; no separate design.md or mockups: the
  screens are this file's "Views" and "Look"). Checked in headless Edge at phone, iPad and TV widths;
  not yet tried on real devices or at a party.

## Rule mode: free-form

The phones replace the slips of paper. The server deals the words and nothing else. Describing,
discussing, voting and revealing all happen out loud. The server doesn't track rounds, votes, who is
out, or who won. **Why:** the user wants it as simple as possible: a big word on each phone, and a
Reroll button on the table.

## Rules (as played at this table)

- **3–8 players.** Start needs at least 3.
- **A deal:** every seated player gets a word on their phone. Most get one word of a pair (the
  civilians); the undercover(s) get the other word. Which word of the pair goes to the undercovers is
  random on every deal.
- **Undercovers per deal:** 1 with 3–5 players, 2 with 6–8 (counted when the words are dealt).
- **No Mr. White.** Every phone always has a word.
- **Nobody is told their role.** Your phone shows only your word. You find out you're the undercover by
  listening to the others.
- **Playing it out:** players take turns describing their word without saying it, then vote someone
  out. A player who is voted out shows their phone. The civilians win by voting out every undercover;
  the undercovers win if they survive until only two players are left. All of this is out loud.
- **Reroll:** the table's Reroll button deals a new pair and new roles to everyone. **Start game** deals
  the first pair, so the table doesn't tap Reroll at the start.
- **No repeats:** a pair isn't dealt twice in one game (until Reset or Play again).

## Words

- `priv/undercover/pairs.txt`, one pair per line: `Coffee | Tea`. Lines starting with `#` and blank
  lines are ignored. Two sections, `# General` and `# 18+`, but the game uses one mixed pool.
- About 1000 pairs, about 30% of them 18+ party words. Plain international English: no slang or things
  only Americans would know.
- **Why:** the user's choice (2026-10-13): one mixed pool, so the table stays just Reroll.

## Views

**Phone (player, private)**
- Your word, big, on a paper slip. Nothing about your role.
- Under it: "1 player has a different word. It could be you." (or "2 players have…").
- On every new deal the slip is dealt in again, so everyone sees the word changed, even when the new
  word looks a lot like the old one.
- No buttons.

**Middle device (table, shared)**
- Every seated player's name, with the *away* tag on disconnected players. No counts, no words, no
  roles. The table never shows a word.
- The number of undercovers in this deal, big.
- Controls: **Reroll**, **Reset**, and **Change game** in the lobby.

## Kicked players (Undercover specifics)

The platform rule (grace period, then kick) applies. The kicked player's word leaves the game. The
table's undercover count stays as it was dealt, so a kick doesn't reveal what the kicked player was.
If only one player is left, that player wins (the platform's "last player left wins"). Otherwise play
goes on, and the table can Reroll.

## Look

Built on the redesign (`docs/mockups/redesign/style.css`, i.e. `assets/css/app.css`) and its tokens.
The one loud thing is the word on the phone; everything else follows the Liar's Dice screens.
- **Phone:** the word in Baloo 2 800, ink on a paper (`--paper`) slip with the ink outline and hard
  shadow, tilted slightly. Font size steps down for longer words, so the longest word still fits on one
  line on a 320 px phone. A new deal deals the slip in (a short slide-and-land, like the `land`
  animation), only for deals that happen while the page is open.
- **Table:** the Liar's Dice layout with a petrol-teal felt (`--felt: #2a8f8a`): the undercover count
  on the left where the dice total is, a line of instructions in the middle, **Reroll** on the right.
- **Shelf box:** a near-black box with the logo in paper, and two paper slips that almost say the same
  thing ("Coffee", "Tea"): the game in one picture. Tag "3 to 8 players".

## Open questions (Undercover)

None right now.
