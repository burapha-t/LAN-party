# CLAUDE.md — LAN Party

Read this first. It is the source of truth for what this project is, what has been decided, and what is
still open. It covers the **platform** (things shared by every game). Each game has its own docs folder;
see "Where things live".

## Status

- **Stage:** Design (brainstorming, architectural path). No code yet.
- **Process:** context → clarifying questions (done) → approaches (next) → design → written spec →
  implementation plan → code. No code until the user approves the spec and the plan.
- Keep this file updated: when an open question is answered, move it to "Decisions" with a one-line reason.

## Where things live

| Path | What |
|---|---|
| `CLAUDE.md` | Platform-level context (this file) |
| `uno/docs/` | Everything about the UNO game. **Read `uno/docs/README.md` before working on UNO.** |

- Each game is served at its own URL path: players open `/<game>` (e.g. `http://<lan-ip>:<port>/uno`),
  middle devices open `/<game>/table`.
- Each game's docs live in `<game>/docs/`. Where the code goes depends on the stack, so that's decided
  together with the stack.

## Games

| Game | Status | What it is | Docs |
|---|---|---|---|
| UNO | First game, in design | The card game. Phone: your hand. Table: discard pile, whose turn, every player's card count. | `uno/docs/` |
| Liar's Dice | Planned, not designed yet | Bluffing dice game. Phone: your dice. Table: the current bid, each player's dice count, the reveal. | none yet |
| Quiplash | Planned, not designed yet | Everyone answers a prompt with something funny on their phone, then everyone votes. Table: answers side by side, scores. | none yet |

## The problem

Friends gather in someone's apartment for a party. They want to play a game together, but games like
card games and board games need physical things: a deck of cards, a board, pieces. If nobody brought
them, nobody can play.

## The idea

Replace the physical game kit with a web game hosted on the host's own computer, over the local network:

1. The host runs the server (this repo) on their own computer.
2. Guests connect to the same Wi-Fi.
3. Guests open a browser at the host's LAN IP and port, e.g. `http://192.168.1.23:4000/uno`. No app install.
4. The server holds the shared game state. Every device sees updates right away.

## Success criteria (confirmed by the user)

- The host starts the server with one command, and the log shows the URLs to share.
- 2–8 players join from their phone browsers on the same Wi-Fi with nothing to install.
- A full UNO round can be played to a winner, with a TV or iPad as the table and no physical cards.
- A phone that briefly locks or switches apps (shorter than the grace period) keeps its seat and hand.
- Every UNO rule in `uno/docs/README.md` is enforced by the server. An illegal play is rejected, and the
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
- **The URL picks the role.** Players open `/<game>`; middle devices open `/<game>/table`. Guests only
  ever see the player URL, so they can't become the table by accident.

### Joining, lobby, queue

- At startup, the server prints the player URL and the table URL for each game
  (e.g. `http://<lan-ip>:<port>/uno` and `.../uno/table`) to the log. The host tells the players.
  No QR code or on-screen address needed.
- A player joins by entering a **name**. Names are required and must be unique among current players.
- Max **8 players** per game.
- Someone who joins while a game is in progress waits in a **queue** for the next game.
- When a game ends ("Play again") or the middle device resets it, everyone, including the queue, goes
  back to the lobby for the next game.

### Disconnects

- When a player's connection drops, they get a **short grace period** (around 30 s; tune later).
  - If they reconnect in time, they keep their seat and their hand.
  - If not, they're **kicked**. Their cards and their turn are removed from the game, and play continues
    with the rest. They can rejoin, and then wait in the queue like any late joiner.
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

1. **Code layout:** where the UNO code lives in the Phoenix project vs. `uno/docs/` (decide in design).

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
| Each game lives at its own path (`/uno`); its docs go in `<game>/docs/` | User's choice; keeps games separate |
| First game: UNO (details in `uno/docs/`) | User's choice |
| Stack: Elixir + Phoenix LiveView, no database | Real-time views and disconnect detection built in; user wants to learn something new |
| Success criteria confirmed, plus "server enforces every UNO rule" | Confirmed by the user 2026-10-12 |
| Role by URL: `/<game>` for players, `/<game>/table` for middle devices | Guests share one URL and can't become the table by accident |
| Players join with a name, unique among current players | Needed to tell players apart on the table and in prompts (e.g. 7-0 swap) |
| Game end or reset → everyone, including the queue, back to the lobby | One simple point where late joiners get in |
| Planned games after UNO: Liar's Dice and Quiplash | User's choice. Liar's Dice is a small build that fits the kick and last-player-wins rules; Quiplash has no turns, so the shared lobby code won't assume turn-based play |

## Working agreements for future sessions

- Don't build anything the user hasn't agreed to. Ask when a choice belongs to the user.
- Prefer the simplest thing that works at a real party: one command to start, one URL to join.
- UNO is built first; the other games in "Games" are planned, not designed. Keep game logic separate
  from lobby/room logic so a second game can be added later, but don't build a generic game framework
  until there is a second game.
