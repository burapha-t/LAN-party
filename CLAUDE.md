# CLAUDE.md — LAN Party

Read this first. It is the source of truth for what this project is, what has been decided, and what is
still open. It covers the **platform** (things shared by every game). Each game has its own docs folder;
see "Where things live".

## Status

- **Stage:** First build compiles and `mix test` passes (147 tests, 2026-10-12). Not yet tried on real
  devices. Still to do: run `mix phx.server` and open it from a phone, compare the screens with
  `docs/mockups/` in a browser, and the party test (`docs/uno/plan.md` Task 13 Step 4).
- **Process:** context → clarifying questions (done) → approaches (done) → design (done) → written spec
  (`docs/uno/design.md`, approved 2026-10-12, including the game-picker revision) → implementation plan
  (`docs/uno/plan.md`; the user hasn't reviewed it, but asked another session to implement it) → code
  (written 2026-10-12 by subagents; the plan was updated to match the code review's fixes; compiled and
  tested once Elixir 1.20.4 / OTP 29 was installed).
- **Liar's Dice:** clarifying questions done → design (approved in chat 2026-10-12) → written spec
  (`docs/liars-dice/design.md`) → implementation plan (`docs/liars-dice/plan.md`) → code (built
  2026-10-12 by two subagents on branch `liars-dice`, styled on the redesign; `mix test` passes with 212
  tests). Not yet tried on real devices: still to do are the party test and watching the roll animation
  on an iPhone and an Android phone (`design.md` §7 "Manual").
- **Toolchain on the host PC:** Erlang/OTP 29.1.1 and Elixir 1.20.4 were installed with winget, which
  didn't add them to PATH. Until it's added, prefix commands, e.g. in PowerShell:
  `$env:Path = "C:\Program Files\Erlang OTP\bin;C:\Program Files\Elixir\bin;" + $env:Path`.
- Keep this file updated: when an open question is answered, move it to "Decisions" with a one-line reason.

## Where things live

| Path | What |
|---|---|
| `CLAUDE.md` | Platform-level context (this file) |
| `docs/` | All docs: one folder per game (`docs/<game>/`) plus `docs/mockups/` |
| `docs/uno/` | Everything about the UNO game. **Read `docs/uno/README.md` before working on UNO.** |
| `docs/uno/design.md` | Design spec for the first build (platform + UNO): screens, architecture, rules engine, tests |
| `docs/uno/plan.md` | Implementation plan for the first build: 13 tasks, test-first |
| `docs/liars-dice/` | Everything about Liar's Dice. **Read `docs/liars-dice/README.md` before working on it.** `design.md` is its spec, including the platform changes for a second game; `plan.md` is the implementation plan it was built from |
| `docs/mockups/` | Static HTML mockups of every phone and table screen, grouped by game: `<game>/phone/`, `<game>/table/`, plus `platform/` for the screens every game shares (join, waiting, phone lobby, queue, reconnecting, the game picker); shared `style.css`. Build the real screens to match them |
| `docs/mockups/redesign/` | Redesign pass (ink outlines, hard offset shadows, buttons that press down), with its own `style.css`. UNO and Liar's Dice screens are done, in `uno/` and `liars-dice/` with the same file names as the originals. The platform screens aren't redone yet, so it hasn't replaced the originals. The app's UNO screens follow it; `assets/css/app.css` is its `style.css` plus the platform rules moved onto its tokens (2026-10-12) |
| `lib/`, `test/`, ... | The Phoenix project (platform + UNO), hand-written without `mix phx.new`; layout in `docs/uno/design.md` §3 |
| `.superpowers/sdd/plan/` | The implementing session's ledger (`progress.md`: rulings, deferred items) and code reviews |

- Two URLs for the whole night: players open `/` (e.g. `http://<lan-ip>:<port>/`), middle devices open
  `/table`. Games don't have their own URLs; the table picks the game and every phone follows.
- Each game's docs live in `docs/<game>/`. Its code lives in the Phoenix project under
  `lib/lan_party/<game>/` and `lib/lan_party_web/live/<game>/`.

## Games

| Game | Status | What it is | Docs |
|---|---|---|---|
| UNO | First game, in design | The card game. Phone: your hand. Table: discard pile, whose turn, every player's card count. | `docs/uno/` |
| Liar's Dice | Second game, built | Bluffing dice game, played free-form (bids are out loud). Phone: your dice, with a rolling animation. Table: each player's dice count, the total, Roll, a face picker that lights up matching dice on every phone, and "take a die". | `docs/liars-dice/` |
| Quiplash | Planned, not designed yet | Everyone answers a prompt with something funny on their phone, then everyone votes. Table: answers side by side, scores. | none yet |
| Paranoia | Planned, not designed yet | One player privately sends a question about the group ("Who here would…?") to another player's phone. That player says a name out loud; a coin flip decides if the table reveals the question. | none yet |
| Who wrote it? | Planned, not designed yet | The table asks a personal question; everyone answers anonymously on their phone. The table shows the answers one by one and everyone votes on who wrote each. Points for guessing right and for fooling others. | none yet |
| Love Letter | Planned, not designed yet | Tiny 16-card deck. Each turn, draw one card and play one; knock others out by guessing the card they hold. Phone: your card. Table: played cards, who's still in. | none yet |
| Never Have I Ever | Planned, not designed yet | The table shows a statement, everyone secretly taps "I have" on their phone, and the table reveals only how many did. | none yet |
| Killer | Planned, not designed yet | Short game played during a break, not all night. Each phone gives a secret target and a sneaky task (e.g. get them to say "banana"); pull it off and you take over their target. | none yet |

## The problem

Friends gather in someone's apartment for a party. They want to play a game together, but games like
card games and board games need physical things: a deck of cards, a board, pieces. If nobody brought
them, nobody can play.

## The idea

Replace the physical game kit with a web game hosted on the host's own computer, over the local network:

1. The host runs the server (this repo) on their own computer.
2. Guests connect to the same Wi-Fi.
3. Guests open a browser at the host's LAN IP and port, e.g. `http://192.168.1.23:4000/`. No app install.
4. The server holds the shared game state. Every device sees updates right away.

## Success criteria (confirmed by the user)

- The host starts the server with one command, and the log shows the URLs to share.
- 2–8 players join from their phone browsers on the same Wi-Fi with nothing to install.
- A full UNO round can be played to a winner, with a TV or iPad as the table and no physical cards.
- A phone that briefly locks or switches apps (shorter than the grace period) keeps its seat and hand.
- Every UNO rule in `docs/uno/README.md` is enforced by the server. An illegal play is rejected, and the
  phone shows why.

## Platform design

### Devices and roles

- **Phone = player view (private).** One per player. Shows only that player's own state and actions.
- **Middle device = table view + flow control (shared).** Sits in the middle of the room. Shows the
  public game state. It also controls the flow: game settings, start/reset a game, change the game.
- **Several middle devices can be connected at once.** Example: the TV shows the table while an iPad is
  used as the controller. All of them show the same state, and any of them can control the flow.
- Any device with a browser can be a middle device (laptop, PC, iPad, TV). Don't design around a
  specific one.
- **The URL picks the role.** Players open `/`; middle devices open `/table`. Guests only ever see the
  player URL, so they can't become the table by accident.
- **The table picks the game; phones follow.** `/table` starts on a "Select the game" screen listing every
  game in "Games" (unbuilt ones are shown as not built yet). When the table picks one, every connected
  phone switches to it on its own. Nobody types a new URL.

### Joining, lobby, queue

- At startup, the server prints two URLs to the log: players `http://<lan-ip>:<port>/` and table
  `http://<lan-ip>:<port>/table`. The host tells the players. No QR code or on-screen address needed.
- A player joins **once per night** at `/` by entering a **name**. Names are required and must be unique
  among current players. Who has joined belongs to the night, not to a game.
- Before the table picks a game, phones show "Waiting for the table to pick a game".
- Max **8 players** per game. Seats go in arrival order; anyone beyond 8 waits in the queue. A seat freed
  in the lobby (someone was kicked) goes straight to the first person in the queue.
- Someone who joins while a game is in progress waits in a **queue** for the next game.
- When a game ends ("Play again") or the middle device resets it, everyone, including the queue, goes
  back to the lobby for the next game.
- **Change game** is only available in a game's lobby (Reset first if a round is running), so no round is
  ever cut off. It returns the table to "Select the game". Picking a game puts everyone who has joined
  into its lobby in arrival order, up to that game's player limit; the rest wait in its queue.

### Disconnects

- When a player's connection drops, they get a **short grace period** (around 30 s; tune later).
  - If they reconnect in time, they keep their seat and their hand.
  - If not, they're **kicked**: forgotten for the night. Their cards and their turn are removed from the
    game, and play continues with the rest. They can rejoin (the join screen fills in their old name),
    and then wait in the queue like any late joiner.
- The same grace period applies whatever the phone is showing: waiting for a game, a lobby, a queue, or
  a round.
- **If only one player is left, that player wins.**
- _Assumption:_ "reconnect" means the same browser on the same device comes back (the browser remembers
  who it is).
- _Assumption:_ if it's the disconnected player's turn, the game waits for them until they return or
  the grace period ends.

### Rule enforcement is chosen per game

Each game uses one of two modes, which is a property of that game:

- **Enforced:** the server checks every move and rejects illegal ones. Use it where a mistake would need
  an "undo / take the card back" feature.
- **Free-form:** the server moves things where players say, like a real table, and players police the
  rules themselves. Use it where the looseness is part of the fun.

## Tech stack: Elixir + Phoenix LiveView, no database

Chosen by the user, who wants to learn a stack they haven't used before. Why it fits:
- **Real-time is built in.** Each open page is a LiveView process over a WebSocket, and the server
  pushes changes.
- **Disconnects are detected per process,** which is the hook for the grace period and the kick.
- **The two roles (phone, middle device) are LiveViews.** Several middle devices subscribe to the same
  `Phoenix.PubSub` topic.
- **Game state lives in one GenServer,** so actions are applied one at a time with no races.
- **One command to start:** `mix phx.server`.

Known costs: a functional/OTP learning curve, and Erlang + Elixir have to be installed on Windows first.
Animations and drag-and-drop would need small JS hooks.
Considered and not chosen: Gleam + Lustre, C# + Blazor Server, TypeScript + Colyseus, Go.

### Gotchas (apply to any stack)

- Bind the server to `0.0.0.0`, not `localhost`/`127.0.0.1`, or guests can't reach it. (Phoenix's dev
  config defaults to `127.0.0.1`.)
- Windows Firewall must allow inbound connections on the port.
- Plain `http://` on a LAN IP is **not a secure context**, so browser APIs that need HTTPS (e.g. Wake
  Lock, Clipboard) are unavailable. Phones will sleep; the grace period exists for this.
- Concurrent actions (e.g. UNO jump-in) must be applied one at a time in arrival order on the server.

## Open questions (platform)

None right now.

## Decisions

| Decision | Reason |
|---|---|
| Host on the user's own computer; guests join with a browser via LAN IP + port | No physical game kit, no cloud, nothing for guests to install |
| Phones = private player view; middle device(s) = shared table view + flow control | Mirrors a real table: private hand, public pile |
| Several middle devices allowed, all with control | e.g. TV as display, iPad as controller |
| Rule enforcement chosen per game (enforced or free-form) | Enforcing prevents mistakes in some games; looseness is more fun in others |
| Max 8 players per game | User's choice for now |
| Late joiners wait in a queue for the next game | Don't disrupt a game in progress |
| Disconnect → ~30 s grace period → kick; a kicked player's cards and turn leave the game | Phones sleep between turns; removing the player is the simplest way to handle a kick |
| Last player left wins | Simplest end condition when others drop |
| LAN address is printed in the server log only | Host shares it with players; simplest |
| Each game's docs go in `docs/<game>/`; the screen mockups in `docs/mockups/` | User's choice; keeps games separate, all docs in one folder (moved from `<game>/docs/` and `mockups/`, 2026-10-12). (Per-game URL paths were replaced by the game picker, below.) |
| First game: UNO (details in `docs/uno/`) | User's choice |
| Stack: Elixir + Phoenix LiveView, no database | Real-time views and disconnect detection built in; user wants to learn something new |
| Success criteria confirmed, plus "server enforces every UNO rule" | Confirmed by the user 2026-10-12 |
| Role by URL: `/` for players, `/table` for middle devices (replaces `/<game>` and `/<game>/table`, 2026-10-12) | One player URL for the whole night; guests can't become the table by accident |
| The table picks the game from a "Select the game" screen; phones follow on their own | User's choice (2026-10-12): nobody types a new URL when the game changes |
| Players join once per night; who has joined and the grace/kick rules belong to the night, not a game | Follows from one URL for the night |
| Change game only from a game's lobby; picking a game seats everyone in arrival order up to its limit | No round is cut off by switching; works like "Play again" |
| Players join with a name, unique among current players | Needed to tell players apart on the table and in prompts (e.g. 7-0 swap) |
| Game end or reset → everyone, including the queue, back to the lobby | One simple point where late joiners get in |
| Architecture: pure rules module per game + one Room process for the platform state | Standard Elixir shape; one process gives arrival-order handling for free; rules testable without a browser. Details in `docs/uno/design.md` |
| Code layout: standard Phoenix project at the repo root; docs live in `docs/` | Matches Phoenix guides, which helps while learning the stack |
| More than 8 people: seats in arrival order; seated players keep their seats at "Play again" | Simplest; revisit if parties regularly exceed 8 |
| A seat freed in the lobby goes to the first person in the queue at once | User's choice (2026-10-12): don't make them wait an extra round |
| A kicked player's join screen fills in their old name | User's choice (2026-10-12): matches the mockup; one tap to rejoin |
| Fonts load from Google Fonts; offline, pages fall back to the system font | User's choice (2026-10-12): most party Wi-Fi has internet; the game works either way |
| Planned games after UNO: Liar's Dice, Quiplash, Paranoia, Who wrote it?, Love Letter, Never Have I Ever, Killer | User's choice. Liar's Dice is a small build that fits the kick and last-player-wins rules; Quiplash has no turns, so the shared lobby code won't assume turn-based play; Paranoia, Who wrote it?, Never Have I Ever and Killer are about the people in the room; Love Letter is a tiny card game |
| Liar's Dice is free-form: the server rolls, counts dice, and decides who's out and who won; bids, turns and "Liar!" happen out loud | User's choice (2026-10-12): as close to playing by hand as possible |
| Liar's Dice: the table's Roll button rolls every phone at once, with a 3D rolling animation | User's choice (2026-10-12): one tap, nobody can secretly re-roll; the animation makes it fun |
| Liar's Dice count: players show their phones; the table picks the bid's face (2–6), and matching dice and 1s light up on every phone; the table never shows the number | User's choice (2026-10-12): quicker counting that keeps the suspense |
| Liar's Dice: 1s are wild | User's choice (2026-10-12): the classic rule; why the face picker goes 2 to 6 |
| Liar's Dice: the table takes one die from whoever lost the challenge (confirm panel, no undo); 0 dice = out; last player with dice wins | User's rule (2026-10-12); the panel is the confirm step, like UNO's "draw for player" |
| A second game → the Room hands moves to the picked game through a small shared interface (`LanParty.Game`) | Planned in the UNO spec for when a second game arrives; details in `docs/liars-dice/design.md` §3 |
| Table game picker: tapping a box only selects it (it grows and lights up, on that table device only); the side panel's Play button picks the game. Supersedes "tapping a box picks the game" and the mockup `platform/table/index.html` | User's choice (2026-10-12): both boxes looked lit at once; one clear choice before everyone's phone switches |
| Liar's Dice is styled on the redesign (`docs/mockups/redesign/liars-dice/`): no background glow, a wine-red felt | User's choice (2026-10-12): build on the new redesign, which dropped the glows (supersedes `design.md` §2 item 13) |

## Working agreements for future sessions

- Don't build anything the user hasn't agreed to. Ask when a choice belongs to the user.
- Prefer the simplest thing that works at a real party: one command to start, one URL to join.
- UNO and Liar's Dice are built; the other games in "Games" are planned, not designed. Keep
  game logic separate from lobby/room logic. Games share only the small `LanParty.Game` interface
  (`docs/liars-dice/design.md` §3); don't grow it into a generic framework until a game needs more.
