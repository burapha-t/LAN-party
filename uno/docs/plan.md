# UNO First Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Phoenix LiveView server on the host's computer where 2–8 phones join once at `/`, the table
at `/table` picks UNO, and everyone plays a full, rule-enforced round with a TV or iPad as the table.

**Architecture:** Pure UNO rules (`LanParty.Uno.Rules`, no processes) wrapped by one GenServer
(`LanParty.Room`) that owns the night: names, the picked game, seats, queue, settings, disconnects and
kicks. Two LiveViews (`PlayerLive` at `/`, `TableLive` at `/table`) call the Room and re-render from
PubSub broadcasts; once UNO is picked they render UNO LiveComponents for the UNO screens.

**Tech Stack:** Elixir ≥ 1.15, Erlang/OTP ≥ 26, Phoenix 1.8 (whatever `phx_new` installs), Phoenix
LiveView ≥ 1.0. Styling is the plain CSS of `mockups/style.css`, copied into `assets/css/app.css`
(the generated asset pipeline still builds it). No database, no custom JavaScript.

**Spec:** `uno/docs/design.md`. Rules: `uno/docs/README.md`. Platform: `CLAUDE.md`. Read all three.

## Global Constraints

- **No git commits.** The user commits. Skip any "commit" habit; leave changes in the working tree.
- App name `lan_party`; modules `LanParty.*` (core) and `LanPartyWeb.*` (web). Phoenix project at the
  repo root. `uno/docs/` and `CLAUDE.md` stay where they are.
- No Ecto, no mailer, no JS hooks.
- Server binds `{0, 0, 0, 0}`, port 4000. Start command: `mix phx.server`.
- Grace period: config `:lan_party, :grace_ms`, default `30_000` (tests: `50`).
- Max 8 seats. Names are trimmed, 1–20 characters, unique ignoring case.
- Draw for player: amount 1–10, default 2. It never changes the turn or the jump-in window.
- All house rules off by default: `%{stack_plus2: false, stack_plus4: false, seven_zero: false, jump_in: false}`.
- **Screens match `mockups/`** (static HTML + `mockups/style.css`). The app uses that stylesheet as
  is, and every screen reuses the mockup's markup and class names. Copy text comes from the mockups.
  The mockups were still being edited while this plan was written: when a UI task's markup differs
  from the current mockup file it names, the mockup wins for markup and copy; this plan wins for
  behavior.
- The phone never shows the pile or the current color (README "Views").
- Two URLs: `/` (players) and `/table` (tables). No per-game URLs.
- No generic game framework. Only UNO; the other 7 games appear in the picker as "Not built yet".

## Review Focus

1. **Double-tap / stale tap:** the same card sent twice must give an error for the second, never a crash
   or a double play. Test in Task 4.
2. **Same browser, two tabs:** closing one tab must not mark the player away or start the grace timer.
   Test in Task 9.
3. **Names that differ only by case or spaces** (`"Alice"` vs `" alice "`) must be rejected as taken.
   Test in Task 8.
4. **Room crash:** every open page must reload to a working screen, not freeze. Test in Task 10.
5. **Both piles run dry** (heavy "draw for player" or long stacks): draw what's there, never crash.
   Test in Task 7.

## File Structure

| File | Responsibility |
|---|---|
| `lib/lan_party/lan_address.ex` | Find LAN IPs; build the startup banner |
| `lib/lan_party/games.ex` | The 8 games for the picker; only `:uno` playable |
| `lib/lan_party/uno/card.ex` | Card struct, labels, sorting |
| `lib/lan_party/uno/deck.ex` | The 108-card deck, shuffle |
| `lib/lan_party/uno/rules.ex` | Game struct and every UNO rule (pure) |
| `lib/lan_party/uno/view.ex` | What a phone / the table may see of a game (pure) |
| `lib/lan_party/room.ex` | Platform state GenServer for the night: people, picked game, seats, queue, settings, phases, grace, kicks |
| `lib/lan_party_web/plugs/player_token.ex` | Gives each browser a player token in the session |
| `lib/lan_party_web/components/layouts/root.html.heex` | Root layout: fonts, stylesheet, SVG sprite |
| `assets/css/app.css` | A copy of `mockups/style.css` |
| `lib/lan_party_web/live/player_live.ex` | `/`: join, waiting for a game, reconnect overlay; hosts the game component |
| `lib/lan_party_web/live/table_live.ex` | `/table`: "Select the game"; hosts the game component |
| `lib/lan_party_web/live/uno/components.ex` | Shared UNO function components: card face, toast |
| `lib/lan_party_web/live/uno/player_component.ex` | UNO phone screens (LiveComponent) |
| `lib/lan_party_web/live/uno/table_component.ex` | UNO table screens (LiveComponent) |
| `test/support/uno_helpers.ex` | Builders for deterministic games in tests |

---

### Task 1: Toolchain, Phoenix project, LAN binding, startup banner

**Files:**
- Generate: the Phoenix project at the repo root
- Modify: `config/config.exs`, `config/dev.exs`, `config/test.exs`, `lib/lan_party/application.ex`
- Create: `lib/lan_party/lan_address.ex`
- Test: `test/lan_party/lan_address_test.exs`

**Interfaces:**
- Produces: `LanParty.LanAddress.private_ipv4?/1`, `list/0 :: [{String.t(), :inet.ip4_address()}]`,
  `banner/2 :: String.t()`, `print_banner/1`. Config keys `:lan_party, :grace_ms` and `:print_urls`.

- [ ] **Step 1: Install Erlang/OTP and Elixir on Windows**

Follow https://elixir-lang.org/install.html#windows (the installer sets up both Erlang/OTP and Elixir).
Open a **new** terminal, then:

Run: `elixir --version`
Expected: `Erlang/OTP 26` (or newer) and `Elixir 1.15` (or newer).

- [ ] **Step 2: Install Hex and the Phoenix generator**

Run: `mix local.hex --force` then `mix archive.install hex phx_new --force`
Expected: both finish without errors.

- [ ] **Step 3: Generate the project in the repo root**

From `D:\project\LAN-party`:

Run: `mix phx.new . --app lan_party --module LanParty --no-ecto --no-mailer`
Answer `Y` to "directory already exists, continue?" and `Y` to "Fetch and install dependencies?".
If it asks to overwrite an existing file (`CLAUDE.md`, anything in `uno/`), answer `n`.

- [ ] **Step 4: Check the generated project works**

Run: `mix test`
Expected: all generated tests pass.

- [ ] **Step 5: Write the failing banner test**

Create `test/lan_party/lan_address_test.exs`:

```elixir
defmodule LanParty.LanAddressTest do
  use ExUnit.Case, async: true

  alias LanParty.LanAddress

  test "recognizes private IPv4 ranges" do
    assert LanAddress.private_ipv4?({192, 168, 1, 23})
    assert LanAddress.private_ipv4?({10, 0, 0, 5})
    assert LanAddress.private_ipv4?({172, 16, 0, 1})
    assert LanAddress.private_ipv4?({172, 31, 255, 1})
    refute LanAddress.private_ipv4?({172, 32, 0, 1})
    refute LanAddress.private_ipv4?({127, 0, 0, 1})
    refute LanAddress.private_ipv4?({8, 8, 8, 8})
  end

  test "banner lists the player and table URLs for each address" do
    banner = LanAddress.banner([{"Wi-Fi", {192, 168, 1, 23}}, {"vEthernet", {172, 20, 0, 1}}], 4000)

    assert banner =~ "LAN Party is running."
    assert banner =~ "Players: http://192.168.1.23:4000/  (Wi-Fi)"
    assert banner =~ "Table:   http://192.168.1.23:4000/table"
    assert banner =~ "Players: http://172.20.0.1:4000/  (vEthernet)"
  end

  test "banner explains when no LAN address is found" do
    assert LanAddress.banner([], 4000) =~ "No LAN address found. Is this computer on the Wi-Fi?"
  end

  test "list/0 returns only private IPv4 addresses" do
    for {name, ip} <- LanAddress.list() do
      assert is_binary(name)
      assert LanAddress.private_ipv4?(ip)
    end
  end
end
```

- [ ] **Step 6: Run it to see it fail**

Run: `mix test test/lan_party/lan_address_test.exs`
Expected: FAIL, `LanParty.LanAddress.private_ipv4?/1 is undefined (module LanParty.LanAddress is not available)`.

- [ ] **Step 7: Implement `LanParty.LanAddress`**

Create `lib/lan_party/lan_address.ex`:

```elixir
defmodule LanParty.LanAddress do
  @moduledoc """
  Finds this computer's LAN addresses and builds the startup banner with the URLs the host shares.
  Windows often has extra adapters (e.g. WSL), so every private address is listed with its adapter name.
  """

  @doc "True for 10.x.x.x, 172.16–31.x.x and 192.168.x.x."
  def private_ipv4?({10, _, _, _}), do: true
  def private_ipv4?({172, b, _, _}) when b in 16..31, do: true
  def private_ipv4?({192, 168, _, _}), do: true
  def private_ipv4?(_), do: false

  @doc "Private IPv4 addresses of this computer as `{adapter_name, ip}`."
  def list do
    case :inet.getifaddrs() do
      {:ok, interfaces} ->
        for {name, opts} <- interfaces,
            {:addr, ip} <- opts,
            tuple_size(ip) == 4,
            private_ipv4?(ip),
            do: {List.to_string(name), ip}

      {:error, _} ->
        []
    end
  end

  def banner([], _port) do
    "\nLAN Party is running.\n  No LAN address found. Is this computer on the Wi-Fi?\n"
  end

  def banner(addresses, port) do
    lines =
      Enum.flat_map(addresses, fn {name, ip} ->
        base = "http://#{:inet.ntoa(ip)}:#{port}"
        ["  Players: #{base}/  (#{name})", "  Table:   #{base}/table"]
      end)

    Enum.join(["", "LAN Party is running." | lines] ++ [""], "\n")
  end

  def print_banner(port), do: IO.puts(banner(list(), port))
end
```

- [ ] **Step 8: Run the test to see it pass**

Run: `mix test test/lan_party/lan_address_test.exs`
Expected: 4 tests, 0 failures.

- [ ] **Step 9: Bind to the LAN, add config keys, print the banner on boot**

In `config/dev.exs`, in the `LanPartyWeb.Endpoint` config, change `ip: {127, 0, 0, 1}` to
`ip: {0, 0, 0, 0}`. Confirm the same block has `check_origin: false` (generated; keep it — phones
connect from the LAN IP, which the origin check would otherwise reject).

In `config/config.exs`, above the final `import_config "#{config_env()}.exs"` line, add:

```elixir
# Seconds-scale settings for the platform. See CLAUDE.md "Disconnects".
config :lan_party, grace_ms: 30_000, print_urls: true
```

At the end of `config/test.exs`, add:

```elixir
config :lan_party, grace_ms: 50, print_urls: false
```

In `lib/lan_party/application.ex`, replace the last lines of `start/2`
(`opts = [...]` and `Supervisor.start_link(children, opts)`) with:

```elixir
    opts = [strategy: :one_for_one, name: LanParty.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      if Application.get_env(:lan_party, :print_urls, true) do
        LanParty.LanAddress.print_banner(LanPartyWeb.Endpoint.config(:http)[:port])
      end

      {:ok, pid}
    end
```

- [ ] **Step 10: Run everything and try it from a phone**

Run: `mix test`
Expected: all tests pass.

Run: `mix phx.server`
Expected: the log shows `LAN Party is running.` and a `Players: http://<lan-ip>:4000/  (<adapter>)`
line. If Windows asks whether to allow `erl.exe` through the firewall, allow **Private networks**.
Open `http://<lan-ip>:4000/` on a phone on the same Wi-Fi: the Phoenix welcome page loads (it is
replaced in Task 10). Stop the server with Ctrl+C twice.

---

### Task 2: Cards and the deck

**Files:**
- Create: `lib/lan_party/uno/card.ex`, `lib/lan_party/uno/deck.ex`
- Test: `test/lan_party/uno/card_test.exs`, `test/lan_party/uno/deck_test.exs`

**Interfaces:**
- Produces: `%LanParty.Uno.Card{id, color, value}`; `Card.colors/0 :: [:red, :yellow, :green, :blue]`;
  `Card.wild?/1`; `Card.label/1` (lowercase, e.g. `"red 7"`, `"blue +2"`, `"red skip"`, `"Wild +4"`);
  `Card.sort/1`; `Deck.new/0` (108 cards, ids 1–108 in a fixed order); `Deck.shuffle/1`.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/uno/card_test.exs`:

```elixir
defmodule LanParty.Uno.CardTest do
  use ExUnit.Case, async: true

  alias LanParty.Uno.Card

  defp c(id, color, value), do: %Card{id: id, color: color, value: value}

  test "label/1 names a card for messages" do
    assert Card.label(c(1, :red, 7)) == "red 7"
    assert Card.label(c(2, :blue, :draw2)) == "blue +2"
    assert Card.label(c(3, :green, :skip)) == "green skip"
    assert Card.label(c(4, :yellow, :reverse)) == "yellow reverse"
    assert Card.label(c(5, nil, :wild)) == "Wild"
    assert Card.label(c(6, nil, :wild_draw4)) == "Wild +4"
  end

  test "wild?/1 is true only for Wild and +4" do
    assert Card.wild?(c(1, nil, :wild))
    assert Card.wild?(c(2, nil, :wild_draw4))
    refute Card.wild?(c(3, :red, :draw2))
  end

  test "sort/1 orders by color (red, yellow, green, blue, wilds), then numbers, Skip, Reverse, +2" do
    cards = [c(1, :blue, 3), c(2, nil, :wild), c(3, :red, :skip), c(4, :red, 2), c(5, :yellow, 0)]
    assert Enum.map(Card.sort(cards), & &1.id) == [4, 3, 5, 1, 2]
  end
end
```

Create `test/lan_party/uno/deck_test.exs`:

```elixir
defmodule LanParty.Uno.DeckTest do
  use ExUnit.Case, async: true

  alias LanParty.Uno.{Card, Deck}

  test "the deck has the 108 official cards with unique ids" do
    deck = Deck.new()

    assert length(deck) == 108
    assert deck |> Enum.map(& &1.id) |> Enum.sort() == Enum.to_list(1..108)

    for color <- Card.colors() do
      cards = Enum.filter(deck, &(&1.color == color))
      assert length(cards) == 25
      assert Enum.count(cards, &(&1.value == 0)) == 1

      for value <- Enum.to_list(1..9) ++ [:skip, :reverse, :draw2] do
        assert Enum.count(cards, &(&1.value == value)) == 2
      end
    end

    assert Enum.count(deck, &(&1.value == :wild)) == 4
    assert Enum.count(deck, &(&1.value == :wild_draw4)) == 4
  end

  test "the order is fixed: red 0, red 1, red 2, ..., then yellow, green, blue, Wilds, +4s" do
    deck = Deck.new()

    assert Enum.take(deck, 3) == [
             %Card{id: 1, color: :red, value: 0},
             %Card{id: 2, color: :red, value: 1},
             %Card{id: 3, color: :red, value: 2}
           ]

    assert List.last(deck) == %Card{id: 108, color: nil, value: :wild_draw4}
  end

  test "shuffle keeps the same cards" do
    deck = Deck.new()
    assert Enum.sort_by(Deck.shuffle(deck), & &1.id) == deck
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/uno/card_test.exs test/lan_party/uno/deck_test.exs`
Expected: FAIL, `LanParty.Uno.Card.__struct__/1 is undefined`.

- [ ] **Step 3: Implement `Card` and `Deck`**

Create `lib/lan_party/uno/card.ex`:

```elixir
defmodule LanParty.Uno.Card do
  @moduledoc "One UNO card. `id` is unique in the deck, so two identical cards can be told apart."

  @enforce_keys [:id, :color, :value]
  defstruct [:id, :color, :value]

  @type color :: :red | :yellow | :green | :blue
  @type value :: 0..9 | :skip | :reverse | :draw2 | :wild | :wild_draw4
  @type t :: %__MODULE__{id: pos_integer(), color: color() | nil, value: value()}

  @colors [:red, :yellow, :green, :blue]
  @color_rank %{:red => 0, :yellow => 1, :green => 2, :blue => 3, nil => 4}

  def colors, do: @colors

  def wild?(%__MODULE__{value: value}), do: value in [:wild, :wild_draw4]

  @doc "Lowercase name for messages, e.g. red 7, blue +2, Wild +4."
  def label(%__MODULE__{value: :wild}), do: "Wild"
  def label(%__MODULE__{value: :wild_draw4}), do: "Wild +4"
  def label(%__MODULE__{color: color, value: value}), do: "#{color} #{value_label(value)}"

  defp value_label(:skip), do: "skip"
  defp value_label(:reverse), do: "reverse"
  defp value_label(:draw2), do: "+2"
  defp value_label(number), do: Integer.to_string(number)

  @doc "Hand order: red, yellow, green, blue, then wilds; within a color numbers, Skip, Reverse, +2."
  def sort(cards), do: Enum.sort_by(cards, &{@color_rank[&1.color], value_rank(&1.value), &1.id})

  defp value_rank(number) when is_integer(number), do: number
  defp value_rank(:skip), do: 10
  defp value_rank(:reverse), do: 11
  defp value_rank(:draw2), do: 12
  defp value_rank(:wild), do: 13
  defp value_rank(:wild_draw4), do: 14
end
```

Create `lib/lan_party/uno/deck.ex`:

```elixir
defmodule LanParty.Uno.Deck do
  @moduledoc """
  The official 108-card deck: per color one 0 and two each of 1–9, Skip, Reverse and +2; plus 4 Wild
  and 4 +4. `new/0` returns a fixed order (tests rely on it); `shuffle/1` randomizes it.
  """

  alias LanParty.Uno.Card

  def new do
    twice = Enum.to_list(1..9) ++ [:skip, :reverse, :draw2]
    colored = for color <- Card.colors(), value <- [0] ++ twice ++ twice, do: {color, value}
    wilds = List.duplicate({nil, :wild}, 4) ++ List.duplicate({nil, :wild_draw4}, 4)

    (colored ++ wilds)
    |> Enum.with_index(1)
    |> Enum.map(fn {{color, value}, id} -> %Card{id: id, color: color, value: value} end)
  end

  def shuffle(cards), do: Enum.shuffle(cards)
end
```

- [ ] **Step 4: Run them to see them pass**

Run: `mix test test/lan_party/uno/card_test.exs test/lan_party/uno/deck_test.exs`
Expected: 6 tests, 0 failures.

---

### Task 3: Rules setup, the starting card, and views

**Files:**
- Create: `test/support/uno_helpers.ex`, `lib/lan_party/uno/rules.ex`, `lib/lan_party/uno/view.ex`
- Test: `test/lan_party/uno/rules_setup_test.exs`, `test/lan_party/uno/view_test.exs`

**Interfaces:**
- Consumes: `Card`, `Deck` (Task 2).
- Produces:
  - `%LanParty.Uno.Rules{players, hands, draw_pile, discard, color, current, direction, settings,
    jump_in_open, pending, last_played_by, last_challenge, winner}`. The fields are as in design.md §6,
    plus `last_played_by :: token | nil` (who played the top card) and
    `last_challenge :: nil | %{challenger, by, legal, color}` (the result of a challenge, for the
    phones' message; cleared by the next action).
  - `Rules.default_settings/0`, `Rules.new/3` (`new(players, settings, opts \\ [])`, opts `:deck`,
    `:first_player`), `Rules.top_card/1`, `Rules.winner/1`, `Rules.next_player/2`,
    `Rules.apply_action/3 :: {:ok, game} | {:error, atom}`.
  - Pending shapes: `nil | {:start_color, token} | {:drawn, token, card_id} |
    {:penalty, %{total: n, top: :draw2 | :draw4, challenge: nil | %{by: token, legal: boolean, color: color}}}`.
    The challenge's `color` is the color **before** the +4, the one the player must not have held.
  - `View.player_view/2 :: %{hand, top, color, current, my_turn?, prompt, next, others, counts,
    seven_zero?, last_played_by, last_challenge}` (Task 5 adds `stack_options`) and
    `View.table_view/1 :: %{top, color, draw_pile_size, direction, counts, current, pending_total,
    winner}`. Prompts: `nil | :choose_start_color | {:drawn, card} | {:penalty, total, can_challenge?}`.
  - Test helpers `LanParty.UnoHelpers`: `c/3`, `game/1`, `pile/1`, `settings/1`, `ids/1`,
    `deck_starting_with/2`, `restart_room/0`.

- [ ] **Step 1: Add the test helpers**

Create `test/support/uno_helpers.ex`:

```elixir
defmodule LanParty.UnoHelpers do
  @moduledoc "Builders for deterministic UNO games in tests."

  alias LanParty.Uno.{Card, Deck, Rules}

  def c(id, color, value), do: %Card{id: id, color: color, value: value}

  @doc """
  A game in progress, built field by field. Defaults: players a, b, c; "a" to play; red 5 on the
  pile; the jump-in window open (a card was just played); a draw pile of green cards that never
  match red 5.
  """
  def game(fields \\ []) do
    defaults = [
      players: ["a", "b", "c"],
      hands: %{
        "a" => [c(1, :red, 1), c(2, :blue, 9)],
        "b" => [c(3, :green, 3), c(4, :green, 4)],
        "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]
      },
      draw_pile: pile(10),
      discard: [c(100, :red, 5)],
      color: :red,
      current: "a",
      direction: 1,
      settings: Rules.default_settings(),
      jump_in_open: true
    ]

    struct!(Rules, Keyword.merge(defaults, fields))
  end

  @doc "n green number cards (ids 201..), never a 5."
  def pile(n) do
    values = [1, 2, 3, 4, 6, 7, 8, 9]
    for i <- 1..n, do: c(200 + i, :green, Enum.at(values, rem(i - 1, length(values))))
  end

  def settings(overrides), do: Map.merge(Rules.default_settings(), Map.new(overrides))

  def ids(cards), do: cards |> Enum.map(& &1.id) |> Enum.sort()

  @doc "The ordered deck, rearranged so the starting card (dealt after the hands) has `value`."
  def deck_starting_with(player_count, value) do
    deck = Deck.new()
    start = Enum.find(deck, &(&1.value == value))
    {hands, rest} = deck |> List.delete(start) |> Enum.split(7 * player_count)
    hands ++ [start | rest]
  end

  @doc "Gives LiveView tests a fresh app-wide Room."
  def restart_room do
    :ok = Supervisor.terminate_child(LanParty.Supervisor, LanParty.Room)
    {:ok, _pid} = Supervisor.restart_child(LanParty.Supervisor, LanParty.Room)
    :ok
  end
end
```

`restart_room/0` is first used in Task 10, once the Room is in the supervision tree.

With `deck_starting_with(2, 5)` and the fixed deck order, the first player holds ids 1, 2, 3, 4, 5, 7,
8 (red 0, 1, 2, 3, 4, 6, 7), the second holds ids 9–15 (red 8, red 9, red skip, red reverse, red +2,
red 1, red 2), and red 5 (id 6) starts the pile. Later tasks rely on this.

- [ ] **Step 2: Write the failing tests**

Create `test/lan_party/uno/rules_setup_test.exs`:

```elixir
defmodule LanParty.Uno.RulesSetupTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.{Card, Deck, Rules}

  describe "new/3" do
    test "deals 7 cards each and flips the first card" do
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, 5), first_player: "a")

      assert ids(game.hands["a"]) == [1, 2, 3, 4, 5, 7, 8]
      assert length(game.hands["b"]) == 7
      assert %Card{id: 6, value: 5, color: :red} = Rules.top_card(game)
      assert game.color == :red
      assert length(game.draw_pile) == 108 - 14 - 1
      assert game.current == "a"
      assert game.direction == 1
      assert game.pending == nil
      refute game.jump_in_open
    end

    test "a +4 can't start the game; it goes to the bottom of the draw pile" do
      plus4 = Enum.find(Deck.new(), &(&1.value == :wild_draw4))
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, :wild_draw4), first_player: "a")

      refute Rules.top_card(game).value == :wild_draw4
      assert List.last(game.draw_pile).id == plus4.id
      assert length(game.draw_pile) == 108 - 14 - 1
    end

    test "a starting Skip skips the first player" do
      game = Rules.new(["a", "b", "c"], %{}, deck: deck_starting_with(3, :skip), first_player: "a")
      assert game.current == "b"
    end

    test "a starting Reverse flips the direction; the first player still starts" do
      game = Rules.new(["a", "b", "c"], %{}, deck: deck_starting_with(3, :reverse), first_player: "a")
      assert game.direction == -1
      assert game.current == "a"
    end

    test "a starting +2 is a penalty for the first player" do
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, :draw2), first_player: "a")
      assert game.current == "a"
      assert game.pending == {:penalty, %{total: 2, top: :draw2, challenge: nil}}
    end

    test "a starting Wild makes the first player pick the color" do
      game = Rules.new(["a", "b"], %{}, deck: deck_starting_with(2, :wild), first_player: "a")
      assert game.pending == {:start_color, "a"}
      assert game.color == nil
    end

    test "a starting 7 has no effect, even under 7-0" do
      game = Rules.new(["a", "b"], %{seven_zero: true}, deck: deck_starting_with(2, 7), first_player: "a")
      assert game.current == "a"
      assert game.pending == nil
    end

    test "settings are merged over the defaults" do
      game = Rules.new(["a", "b"], %{jump_in: true}, first_player: "a")
      assert game.settings.jump_in
      refute game.settings.stack_plus2
    end
  end

  describe "choosing the starting color" do
    setup do
      %{game: game(pending: {:start_color, "a"}, color: nil, discard: [c(100, nil, :wild)], jump_in_open: false)}
    end

    test "the first player picks it", %{game: game} do
      assert {:ok, game} = Rules.apply_action(game, "a", {:choose_color, :blue})
      assert game.color == :blue
      assert game.pending == nil
      assert game.current == "a"
    end

    test "nobody else can", %{game: game} do
      assert Rules.apply_action(game, "b", {:choose_color, :blue}) == {:error, :not_now}
    end

    test "only the four colors", %{game: game} do
      assert Rules.apply_action(game, "a", {:choose_color, :purple}) == {:error, :invalid_color}
    end
  end

  describe "apply_action/3" do
    test "rejects someone who isn't in the round" do
      assert Rules.apply_action(game(), "zed", :draw) == {:error, :not_in_game}
    end

    test "rejects everything once there is a winner" do
      assert Rules.apply_action(game(winner: "b"), "a", :draw) == {:error, :game_over}
    end

    test "rejects unknown actions" do
      assert Rules.apply_action(game(), "a", :dance) == {:error, :unknown_action}
    end
  end

  test "next_player/2 follows the direction of play" do
    assert Rules.next_player(game(), "c") == "a"
    assert Rules.next_player(game(direction: -1), "a") == "c"
  end
end
```

Create `test/lan_party/uno/view_test.exs`:

```elixir
defmodule LanParty.Uno.ViewTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.View

  test "a phone sees its own hand, sorted, and only counts for everyone else" do
    game =
      game(
        hands: %{
          "a" => [c(1, :blue, 2), c(2, nil, :wild), c(3, :red, 9)],
          "b" => [c(4, :red, 1)],
          "c" => [c(5, :red, 2)]
        }
      )

    view = View.player_view(game, "a")

    assert Enum.map(view.hand, & &1.id) == [3, 1, 2]
    assert view.my_turn?
    assert view.current == "a"
    assert view.next == "b"
    assert view.others == ["b", "c"]
    assert view.counts == %{"a" => 3, "b" => 1, "c" => 1}
    refute Map.has_key?(view, :hands)
    refute view.seven_zero?
  end

  test "the first player is asked for the starting color; nobody else is" do
    game = game(pending: {:start_color, "a"})
    assert View.player_view(game, "a").prompt == :choose_start_color
    assert View.player_view(game, "b").prompt == nil
  end

  test "the table sees counts in seat order, the pile, and the pending total" do
    view = View.table_view(game(pending: {:penalty, %{total: 6, top: :draw2, challenge: nil}}, current: "b"))

    assert view.counts == [{"a", 2}, {"b", 2}, {"c", 2}]
    assert view.top.id == 100
    assert view.color == :red
    assert view.draw_pile_size == 10
    assert view.pending_total == 6
    assert view.current == "b"
    assert view.direction == 1
  end
end
```

- [ ] **Step 3: Run them to see them fail**

Run: `mix test test/lan_party/uno/rules_setup_test.exs test/lan_party/uno/view_test.exs`
Expected: FAIL, `LanParty.Uno.Rules.__struct__/1 is undefined`.

- [ ] **Step 4: Implement the rules skeleton**

Create `lib/lan_party/uno/rules.ex`:

```elixir
defmodule LanParty.Uno.Rules do
  @moduledoc """
  Every UNO rule, as pure functions over a game struct. No processes, no timers.
  The rules are in uno/docs/README.md; how they map to code is in uno/docs/design.md §6.
  """

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

  # More action clauses go above this catch-all.
  defp do_action(_game, _token, _action), do: {:error, :unknown_action}

  ## Helpers

  defp step(%{players: players, direction: direction}, from, steps) do
    index = Enum.find_index(players, &(&1 == from))
    Enum.at(players, Integer.mod(index + direction * steps, length(players)))
  end

  defp penalty(total, top, challenge), do: {:penalty, %{total: total, top: top, challenge: challenge}}
end
```

- [ ] **Step 5: Implement the views**

Create `lib/lan_party/uno/view.ex`:

```elixir
defmodule LanParty.Uno.View do
  @moduledoc """
  What each screen may see of a game: a phone gets only its own hand, the table gets counts.
  The phone never draws the pile; `top` and `color` are there to word error messages.
  See uno/docs/design.md §6 "Views".
  """

  alias LanParty.Uno.{Card, Rules}

  def player_view(%Rules{} = game, token) do
    %{
      hand: Card.sort(Map.get(game.hands, token, [])),
      top: Rules.top_card(game),
      color: game.color,
      current: game.current,
      my_turn?: game.current == token,
      prompt: prompt(game, token),
      next: if(token in game.players, do: Rules.next_player(game, token)),
      others: Enum.reject(game.players, &(&1 == token)),
      counts: Map.new(game.hands, fn {player, cards} -> {player, length(cards)} end),
      seven_zero?: game.settings.seven_zero,
      last_played_by: game.last_played_by,
      last_challenge: game.last_challenge
    }
  end

  def table_view(%Rules{} = game) do
    %{
      top: Rules.top_card(game),
      color: game.color,
      draw_pile_size: length(game.draw_pile),
      direction: game.direction,
      counts: Enum.map(game.players, &{&1, length(game.hands[&1])}),
      current: game.current,
      pending_total: pending_total(game.pending),
      winner: game.winner
    }
  end

  defp prompt(%{pending: {:start_color, token}}, token), do: :choose_start_color

  defp prompt(%{pending: {:drawn, token, card_id}} = game, token),
    do: {:drawn, Enum.find(game.hands[token], &(&1.id == card_id))}

  defp prompt(%{pending: {:penalty, penalty}, current: token}, token),
    do: {:penalty, penalty.total, penalty.challenge != nil}

  defp prompt(_game, _token), do: nil

  defp pending_total({:penalty, %{total: total}}), do: total
  defp pending_total(_pending), do: 0
end
```

- [ ] **Step 6: Run the tests to see them pass**

Run: `mix test test/lan_party/uno`
Expected: all tests pass (Tasks 2–3).

---

### Task 4: Playing, drawing, winning

**Files:**
- Modify: `lib/lan_party/uno/rules.ex`
- Test: `test/lan_party/uno/rules_play_test.exs`

**Interfaces:**
- Consumes: Task 3's `Rules` skeleton and `UnoHelpers`.
- Produces: actions `{:play, card_id, opts}` (`opts` map; `:color` for Wild/+4), `:draw`, `:keep`.
  Errors: `:not_your_turn`, `:not_in_hand`, `:does_not_match`, `:choose_color`,
  `:play_drawn_or_keep`, `:choose_start_color`, `:resolve_penalty`, `:not_now`.
  Private helpers later tasks extend: `check_play/3`, `check_turn_play/3`, `check_opts/4`,
  `effect/5` (one clause per card value, catch-all last), `draw_cards/3`, `advance/3`.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/uno/rules_play_test.exs`:

```elixir
defmodule LanParty.Uno.RulesPlayTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.Rules

  defp play(game, token, id, opts \\ %{}), do: Rules.apply_action(game, token, {:play, id, opts})

  defp hands_with_a(cards) do
    %{"a" => cards, "b" => [c(3, :green, 3), c(4, :green, 4)], "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]}
  end

  describe "playing a card" do
    test "a card of the current color goes on the pile and the turn passes" do
      {:ok, game} = play(game(), "a", 1)

      assert Rules.top_card(game).id == 1
      assert ids(game.hands["a"]) == [2]
      assert game.current == "b"
      assert game.color == :red
      assert game.jump_in_open
      assert game.last_played_by == "a"
    end

    test "a card with the same value matches and changes the color" do
      {:ok, game} = play(game(hands: hands_with_a([c(7, :blue, 5), c(2, :blue, 9)])), "a", 7)
      assert game.color == :blue
    end

    test "a card that matches neither color nor value is rejected" do
      assert play(game(), "a", 2) == {:error, :does_not_match}
    end

    test "only the current player can play" do
      assert play(game(), "b", 3) == {:error, :not_your_turn}
    end

    test "you can only play a card you hold" do
      assert play(game(), "a", 3) == {:error, :not_in_hand}
      assert play(game(), "a", "1") == {:error, :not_in_hand}
    end

    test "a double tap is rejected the second time" do
      {:ok, game} = play(game(), "a", 1)
      assert {:error, _reason} = play(game, "a", 1)
    end

    test "Skip skips the next player" do
      {:ok, game} = play(game(hands: hands_with_a([c(7, :red, :skip), c(2, :blue, 9)])), "a", 7)
      assert game.current == "c"
    end

    test "Reverse flips the direction" do
      {:ok, game} = play(game(hands: hands_with_a([c(7, :red, :reverse), c(2, :blue, 9)])), "a", 7)
      assert game.direction == -1
      assert game.current == "c"
    end

    test "with two players Reverse acts as Skip" do
      game = game(players: ["a", "b"], hands: %{"a" => [c(7, :red, :reverse), c(2, :blue, 9)], "b" => [c(3, :green, 3)]})
      {:ok, game} = play(game, "a", 7)
      assert game.current == "a"
    end

    test "a Wild needs one of the four colors and sets it" do
      game = game(hands: hands_with_a([c(7, nil, :wild), c(2, :blue, 9)]))

      assert play(game, "a", 7) == {:error, :choose_color}
      assert play(game, "a", 7, %{color: :purple}) == {:error, :choose_color}

      {:ok, game} = play(game, "a", 7, %{color: :green})
      assert game.color == :green
      assert game.current == "b"
    end

    test "emptying your hand wins at once" do
      {:ok, game} = play(game(hands: hands_with_a([c(1, :red, 1)])), "a", 1)

      assert Rules.winner(game) == "a"
      assert Rules.apply_action(game, "b", :draw) == {:error, :game_over}
    end

    test "you can't play while the starting color is still to be picked" do
      game = game(pending: {:start_color, "a"}, discard: [c(100, nil, :wild)], color: nil)
      assert play(game, "a", 1) == {:error, :choose_start_color}
    end
  end

  describe "drawing" do
    test "an unplayable card is kept and the turn passes, even if you held a playable card" do
      {:ok, game} = Rules.apply_action(game(), "a", :draw)

      assert ids(game.hands["a"]) == [1, 2, 201]
      assert game.current == "b"
      refute game.jump_in_open
    end

    test "a playable card can be played or kept, and nothing else" do
      {:ok, drawn} = Rules.apply_action(game(draw_pile: [c(90, :red, 8) | pile(3)]), "a", :draw)
      assert drawn.pending == {:drawn, "a", 90}
      assert drawn.current == "a"

      assert play(drawn, "a", 1) == {:error, :play_drawn_or_keep}
      assert Rules.apply_action(drawn, "a", :draw) == {:error, :play_drawn_or_keep}

      {:ok, kept} = Rules.apply_action(drawn, "a", :keep)
      assert kept.current == "b"
      assert kept.pending == nil

      {:ok, played} = play(drawn, "a", 90)
      assert Rules.top_card(played).id == 90
      assert played.current == "b"
      assert played.pending == nil
    end

    test "you can only draw on your turn" do
      assert Rules.apply_action(game(), "b", :draw) == {:error, :not_your_turn}
    end

    test "keeping needs a drawn card" do
      assert Rules.apply_action(game(), "a", :keep) == {:error, :not_now}
    end

    test "an empty draw pile is refilled from the discard pile, keeping its top card" do
      game = game(draw_pile: [], discard: [c(100, :red, 5), c(101, :green, 7), c(102, :blue, 1)])
      {:ok, game} = Rules.apply_action(game, "a", :draw)

      assert length(game.hands["a"]) == 3
      assert Enum.map(game.discard, & &1.id) == [100]
      assert length(game.draw_pile) == 1
    end

    test "with both piles empty nothing is drawn and the turn passes" do
      {:ok, game} = Rules.apply_action(game(draw_pile: [], discard: [c(100, :red, 5)]), "a", :draw)

      assert ids(game.hands["a"]) == [1, 2]
      assert game.current == "b"
    end
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/uno/rules_play_test.exs`
Expected: FAIL, most tests with `{:error, :unknown_action}`.

- [ ] **Step 3: Add the play/draw/keep actions**

In `lib/lan_party/uno/rules.ex`, add these clauses directly **above** the
`# More action clauses go above this catch-all.` comment:

```elixir
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
```

- [ ] **Step 4: Add the helpers**

In the same file, add these functions in the `## Helpers` section (above `defp step/3`):

```elixir
  defp find_card(game, token, card_id) do
    case Enum.find(game.hands[token], &(&1.id == card_id)) do
      nil -> {:error, :not_in_hand}
      card -> {:ok, card}
    end
  end

  # Task 6 replaces this function to add jump-in.
  defp check_play(game, token, card) do
    if game.current == token, do: check_turn_play(game, token, card), else: {:error, :not_your_turn}
  end

  # A play on your own turn, given what the game is waiting for.
  defp check_turn_play(game, token, card) do
    card_id = card.id

    case game.pending do
      nil -> if matches?(game, card), do: :ok, else: {:error, :does_not_match}
      {:drawn, ^token, ^card_id} -> :ok
      {:drawn, _token, _card_id} -> {:error, :play_drawn_or_keep}
      {:start_color, _token} -> {:error, :choose_start_color}
      {:penalty, _penalty} -> {:error, :resolve_penalty}
    end
  end

  # Task 6 replaces this function to add the 7-0 swap target.
  defp check_opts(_game, _token, card, opts) do
    if Card.wild?(card) and Map.get(opts, :color) not in Card.colors(),
      do: {:error, :choose_color},
      else: :ok
  end

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

  # One clause per card value. Later tasks add clauses above the catch-all (numbers and Wild).
  defp effect(game, token, %Card{value: :skip}, _opts, _plus4), do: advance(game, token, 2)

  defp effect(game, token, %Card{value: :reverse}, _opts, _plus4) do
    game = %{game | direction: -game.direction}
    advance(game, token, if(length(game.players) == 2, do: 2, else: 1))
  end

  defp effect(game, token, _card, _opts, _plus4), do: advance(game, token, 1)

  defp advance(game, from, steps), do: %{game | current: step(game, from, steps), pending: nil}

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
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `mix test test/lan_party/uno`
Expected: all tests pass, no compiler warnings.

---

### Task 5: Draw penalties, the +4 challenge, stacking

**Files:**
- Modify: `lib/lan_party/uno/rules.ex`, `lib/lan_party/uno/view.ex`
- Test: `test/lan_party/uno/rules_penalty_test.exs`

**Interfaces:**
- Consumes: Task 4's `check_turn_play/3`, `effect/5`, `draw_cards/3`, `advance/3`.
- Produces: actions `:accept`, `:challenge`; `Rules.stack_options/1 :: [:draw2 | :wild_draw4]` (what
  the player facing the penalty may stack, per the house rules); `View.player_view/2` gains
  `stack_options`. A finished challenge sets `game.last_challenge` to
  `%{challenger: token, by: token, legal: boolean, color: color}`.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/uno/rules_penalty_test.exs`:

```elixir
defmodule LanParty.Uno.RulesPenaltyTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.{Rules, View}

  defp play(game, token, id, opts \\ %{}), do: Rules.apply_action(game, token, {:play, id, opts})

  # "a" holds a red +2 (10), a +4 (11), a red 1 (1), a blue 9 (2).
  # "b" holds a green +2 (12), a +4 (13), a blue +2 (14), a green 3 (3).
  defp penalty_game(fields \\ []) do
    hands = %{
      "a" => [c(10, :red, :draw2), c(11, nil, :wild_draw4), c(1, :red, 1), c(2, :blue, 9)],
      "b" => [c(12, :green, :draw2), c(13, nil, :wild_draw4), c(14, :blue, :draw2), c(3, :green, 3)],
      "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]
    }

    game(Keyword.merge([hands: hands], fields))
  end

  # "a" holds no red card, so their +4 is legal.
  defp fair_plus4_game do
    penalty_game(hands: %{"a" => [c(11, nil, :wild_draw4), c(2, :blue, 9)], "b" => [c(3, :green, 3)], "c" => [c(5, :yellow, 6)]})
  end

  describe "+2" do
    test "puts a penalty on the next player" do
      {:ok, game} = play(penalty_game(), "a", 10)
      assert game.current == "b"
      assert game.pending == {:penalty, %{total: 2, top: :draw2, challenge: nil}}
    end

    test "the target must take it first" do
      {:ok, game} = play(penalty_game(), "a", 10)

      assert play(game, "b", 3) == {:error, :resolve_penalty}
      assert Rules.apply_action(game, "b", :draw) == {:error, :resolve_penalty}
      assert Rules.apply_action(game, "b", :challenge) == {:error, :not_now}
      assert Rules.apply_action(game, "c", :accept) == {:error, :not_your_turn}
    end

    test "accepting draws the total and loses the turn" do
      {:ok, game} = play(penalty_game(), "a", 10)
      {:ok, game} = Rules.apply_action(game, "b", :accept)

      assert length(game.hands["b"]) == 6
      assert game.current == "c"
      assert game.pending == nil
      refute game.jump_in_open
    end

    test "a winning +2 gives nobody a penalty" do
      {:ok, game} = play(penalty_game(hands: %{"a" => [c(10, :red, :draw2)], "b" => [c(3, :green, 3)], "c" => [c(5, :yellow, 6)]}), "a", 10)
      assert Rules.winner(game) == "a"
      assert game.pending == nil
    end

    test "accepting needs a penalty" do
      assert Rules.apply_action(penalty_game(), "a", :accept) == {:error, :not_now}
    end
  end

  describe "+4 and the challenge" do
    test "a +4 played while holding the current color is recorded as a bluff" do
      {:ok, game} = play(penalty_game(), "a", 11, %{color: :green})

      assert game.color == :green
      assert game.current == "b"
      assert game.pending == {:penalty, %{total: 4, top: :draw4, challenge: %{by: "a", legal: false, color: :red}}}
    end

    test "a +4 played without the current color is recorded as fair" do
      {:ok, game} = play(fair_plus4_game(), "a", 11, %{color: :green})
      assert {:penalty, %{challenge: %{legal: true}}} = game.pending
    end

    test "challenging a fair +4: the challenger draws 6 and loses the turn" do
      {:ok, game} = play(fair_plus4_game(), "a", 11, %{color: :green})
      {:ok, game} = Rules.apply_action(game, "b", :challenge)

      assert length(game.hands["b"]) == 7
      assert game.current == "c"
      assert game.pending == nil
      assert game.last_challenge == %{challenger: "b", by: "a", legal: true, color: :red}
    end

    test "challenging a bluff: the bluffer draws 4, the challenger plays on" do
      {:ok, game} = play(penalty_game(), "a", 11, %{color: :green})
      {:ok, game} = Rules.apply_action(game, "b", :challenge)

      assert length(game.hands["a"]) == 3 + 4
      assert length(game.hands["b"]) == 4
      assert game.current == "b"
      assert game.pending == nil
      assert game.color == :green
      assert game.last_challenge.legal == false

      {:ok, game} = play(game, "b", 3)
      assert game.last_challenge == nil
    end

    test "accepting a +4 draws 4 and loses the turn" do
      {:ok, game} = play(penalty_game(), "a", 11, %{color: :green})
      {:ok, game} = Rules.apply_action(game, "b", :accept)

      assert length(game.hands["b"]) == 8
      assert game.current == "c"
    end
  end

  describe "stacking" do
    test "off by default" do
      {:ok, game} = play(penalty_game(), "a", 10)
      assert play(game, "b", 12) == {:error, :resolve_penalty}
    end

    test "Stacking +2s: any +2 on a +2 passes the total on" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus2: true)), "a", 10)
      {:ok, game} = play(game, "b", 12)

      assert game.current == "c"
      assert game.pending == {:penalty, %{total: 4, top: :draw2, challenge: nil}}
    end

    test "Stacking +2s alone doesn't allow a +4 on a +2" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus2: true)), "a", 10)
      assert play(game, "b", 13, %{color: :red}) == {:error, :resolve_penalty}
    end

    test "Stacking +4s: a +4 on a +4 passes the total on and can't be challenged" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus4: true)), "a", 11, %{color: :blue})
      {:ok, game} = play(game, "b", 13, %{color: :yellow})

      assert game.current == "c"
      assert game.pending == {:penalty, %{total: 8, top: :draw4, challenge: nil}}
    end

    test "both on: a +4 on a +2" do
      both = settings(stack_plus2: true, stack_plus4: true)
      {:ok, game} = play(penalty_game(settings: both), "a", 10)
      {:ok, game} = play(game, "b", 13, %{color: :yellow})

      assert game.pending == {:penalty, %{total: 6, top: :draw4, challenge: nil}}
    end

    test "both on: a +2 on a +4 only in the chosen color" do
      both = settings(stack_plus2: true, stack_plus4: true)
      {:ok, game} = play(penalty_game(settings: both), "a", 11, %{color: :blue})

      assert play(game, "b", 12) == {:error, :resolve_penalty}
      {:ok, game} = play(game, "b", 14)
      assert game.pending == {:penalty, %{total: 6, top: :draw2, challenge: nil}}
    end

    test "the phone is told what it may do" do
      {:ok, game} = play(penalty_game(settings: settings(stack_plus4: true)), "a", 11, %{color: :blue})
      view = View.player_view(game, "b")

      assert view.prompt == {:penalty, 4, true}
      assert view.stack_options == [:wild_draw4]
      assert View.player_view(game, "c").prompt == nil
      assert Rules.stack_options(penalty_game()) == []
    end
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/uno/rules_penalty_test.exs`
Expected: FAIL. `+2` tests fail on `pending` being `nil`; `stack_options/1` is undefined.

- [ ] **Step 3: Add `:accept` and `:challenge`**

In `lib/lan_party/uno/rules.ex`, add these clauses above the `# More action clauses go above this
catch-all.` comment:

```elixir
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
```

- [ ] **Step 4: Let the target stack, and make +2/+4 create penalties**

In `check_turn_play/3`, replace the line

```elixir
      {:penalty, _penalty} -> {:error, :resolve_penalty}
```

with

```elixir
      {:penalty, penalty} -> if can_stack?(game, penalty, card), do: :ok, else: {:error, :resolve_penalty}
```

Add these `effect/5` clauses directly above the Skip clause:

```elixir
  defp effect(game, token, %Card{value: :draw2}, _opts, _plus4),
    do: add_penalty(game, token, penalty_total(game.pending) + 2, :draw2, nil)

  defp effect(game, token, %Card{value: :wild_draw4}, _opts, plus4) do
    existing = penalty_total(game.pending)
    # Only a +4 that starts a penalty can be challenged (README "Stacking").
    challenge = if existing == 0, do: Map.put(plus4, :by, token)
    add_penalty(game, token, existing + 4, :draw4, challenge)
  end
```

Add these functions: `stack_options/1` in the `## Queries` section, the rest in `## Helpers`:

```elixir
  @doc "The draw cards the player facing a penalty may stack on it, given the house rules."
  def stack_options(%__MODULE__{pending: {:penalty, %{top: top}}, settings: settings}) do
    both = settings.stack_plus2 and settings.stack_plus4

    case top do
      :draw2 -> if(settings.stack_plus2, do: [:draw2], else: []) ++ if(both, do: [:wild_draw4], else: [])
      :draw4 -> if(both, do: [:draw2], else: []) ++ if(settings.stack_plus4, do: [:wild_draw4], else: [])
    end
  end

  def stack_options(%__MODULE__{}), do: []
```

```elixir
  # A +2 on a +4 must match the color chosen for the +4.
  defp can_stack?(game, %{top: top}, card) do
    card.value in stack_options(game) and
      not (top == :draw4 and card.value == :draw2 and card.color != game.color)
  end

  defp add_penalty(game, token, total, top, challenge),
    do: %{game | current: step(game, token, 1), pending: penalty(total, top, challenge)}

  defp penalty_total({:penalty, %{total: total}}), do: total
  defp penalty_total(_pending), do: 0
```

- [ ] **Step 5: Show the stack options on the phone**

In `lib/lan_party/uno/view.ex`, in `player_view/2`, add this line after `seven_zero?: ...,`:

```elixir
      stack_options: Rules.stack_options(game),
```

- [ ] **Step 6: Run the tests to see them pass**

Run: `mix test test/lan_party/uno`
Expected: all tests pass, no compiler warnings.

---

### Task 6: House rules 7-0 and jump-in

**Files:**
- Modify: `lib/lan_party/uno/rules.ex`
- Test: `test/lan_party/uno/rules_house_test.exs`

**Interfaces:**
- Consumes: Task 4's `check_play/3`, `check_opts/4`, `effect/5`; Task 5's penalty handling.
- Produces: `{:play, id, %{swap_with: token}}` for a 7 under 7-0 (error `:choose_player` without a
  valid target); jump-in plays by anyone while `jump_in_open`.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/uno/rules_house_test.exs`:

```elixir
defmodule LanParty.Uno.RulesHouseTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.Rules

  defp play(game, token, id, opts \\ %{}), do: Rules.apply_action(game, token, {:play, id, opts})

  # 7-0 on; "a" holds a red 7 (7), a red 0 (8) and a blue 9 (2).
  defp seven_zero_game(fields \\ []) do
    hands = %{
      "a" => [c(7, :red, 7), c(8, :red, 0), c(2, :blue, 9)],
      "b" => [c(3, :green, 3)],
      "c" => [c(5, :yellow, 6), c(6, :yellow, 7)]
    }

    game(Keyword.merge([settings: settings(seven_zero: true), hands: hands], fields))
  end

  # Jump-in on; players a–d; a red 5 was just played and "b" is to play.
  defp jump_game(fields \\ []) do
    hands = %{
      "a" => [c(1, :red, 1), c(2, :blue, 9)],
      "b" => [c(3, :green, 3), c(4, :green, 4)],
      "c" => [c(20, :red, 5), c(21, :red, 6), c(22, :red, :draw2)],
      "d" => [c(30, :red, :skip), c(31, :red, :draw2), c(32, :yellow, 8)]
    }

    game(Keyword.merge([players: ["a", "b", "c", "d"], current: "b", settings: settings(jump_in: true), hands: hands], fields))
  end

  describe "7-0" do
    test "a 7 needs another player in the round to swap with" do
      assert play(seven_zero_game(), "a", 7) == {:error, :choose_player}
      assert play(seven_zero_game(), "a", 7, %{swap_with: "a"}) == {:error, :choose_player}
      assert play(seven_zero_game(), "a", 7, %{swap_with: "zed"}) == {:error, :choose_player}
    end

    test "a 7 swaps hands with the chosen player" do
      {:ok, game} = play(seven_zero_game(), "a", 7, %{swap_with: "c"})

      assert ids(game.hands["a"]) == [5, 6]
      assert ids(game.hands["c"]) == [2, 8]
      assert game.current == "b"
    end

    test "a 0 passes every hand one seat in the direction of play" do
      {:ok, game} = play(seven_zero_game(), "a", 8)

      assert ids(game.hands["b"]) == [2, 7]
      assert ids(game.hands["c"]) == [3]
      assert ids(game.hands["a"]) == [5, 6]
      assert game.current == "b"
    end

    test "against the direction of play, hands go the other way" do
      {:ok, game} = play(seven_zero_game(direction: -1), "a", 8)

      assert ids(game.hands["c"]) == [2, 7]
      assert game.current == "c"
    end

    test "with 7-0 off, 7 and 0 are plain numbers" do
      {:ok, game} = play(seven_zero_game(settings: settings([])), "a", 7)
      assert ids(game.hands["a"]) == [2, 8]
    end

    test "a winning 7 doesn't swap" do
      game = seven_zero_game(hands: %{"a" => [c(7, :red, 7)], "b" => [c(3, :green, 3)], "c" => [c(5, :yellow, 6)]})
      {:ok, game} = play(game, "a", 7, %{swap_with: "b"})

      assert Rules.winner(game) == "a"
      assert ids(game.hands["b"]) == [3]
    end
  end

  describe "jump-in" do
    test "anyone can play an identical card out of turn; play continues from them" do
      {:ok, game} = play(jump_game(), "c", 20)

      assert Rules.top_card(game).id == 20
      assert game.current == "d"
      assert game.last_played_by == "c"
    end

    test "only when the house rule is on" do
      assert play(jump_game(settings: settings([])), "c", 20) == {:error, :not_your_turn}
    end

    test "only an identical card" do
      assert play(jump_game(), "c", 21) == {:error, :not_your_turn}
    end

    test "not after someone has drawn" do
      assert play(jump_game(jump_in_open: false), "c", 20) == {:error, :not_your_turn}
    end

    test "never on a Wild" do
      assert play(jump_game(discard: [c(100, nil, :wild)]), "c", 20) == {:error, :not_your_turn}
    end

    test "a jumped-in Skip skips the player after the jumper" do
      {:ok, game} = play(jump_game(discard: [c(100, :red, :skip)], current: "c"), "d", 30)
      assert game.current == "b"
    end

    test "a +2 jumped onto a pending +2 adds up, even with stacking off; the target is spared" do
      game = jump_game(discard: [c(100, :red, :draw2)], pending: {:penalty, %{total: 2, top: :draw2, challenge: nil}})
      {:ok, game} = play(game, "c", 22)

      assert game.current == "d"
      assert game.pending == {:penalty, %{total: 4, top: :draw2, challenge: nil}}
      assert ids(game.hands["b"]) == [3, 4]
    end

    test "the target can escape with an identical +2, even with stacking off" do
      hands = %{"a" => [c(1, :red, 1)], "b" => [c(40, :red, :draw2), c(3, :green, 3)], "c" => [c(21, :red, 6)], "d" => [c(32, :yellow, 8)]}
      game = jump_game(hands: hands, discard: [c(100, :red, :draw2)], pending: {:penalty, %{total: 2, top: :draw2, challenge: nil}})
      {:ok, game} = play(game, "b", 40)

      assert game.current == "c"
      assert game.pending == {:penalty, %{total: 4, top: :draw2, challenge: nil}}
    end

    test "jumping in with your last card wins" do
      hands = %{"a" => [c(1, :red, 1)], "b" => [c(3, :green, 3)], "c" => [c(20, :red, 5)], "d" => [c(32, :yellow, 8)]}
      {:ok, game} = play(jump_game(hands: hands), "c", 20)

      assert Rules.winner(game) == "c"
    end
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/uno/rules_house_test.exs`
Expected: FAIL. 7-0 tests get `:ok` or wrong hands; jump-in tests get `{:error, :not_your_turn}`.

- [ ] **Step 3: Add jump-in to `check_play/3`**

In `lib/lan_party/uno/rules.ex`, replace the whole `check_play/3` function (and its comment) with:

```elixir
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
```

- [ ] **Step 4: Require a swap target for a 7 under 7-0**

Replace the whole `check_opts/4` function (and its comment) with:

```elixir
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
```

- [ ] **Step 5: Add the 7 and 0 effects**

Add these `effect/5` clauses directly above the Skip clause:

```elixir
  defp effect(%{settings: %{seven_zero: true}} = game, token, %Card{value: 7}, opts, _plus4) do
    other = Map.fetch!(opts, :swap_with)
    hands = game.hands |> Map.put(token, game.hands[other]) |> Map.put(other, game.hands[token])
    advance(%{game | hands: hands}, token, 1)
  end

  defp effect(%{settings: %{seven_zero: true}} = game, token, %Card{value: 0}, _opts, _plus4) do
    hands = Map.new(game.players, fn player -> {step(game, player, 1), game.hands[player]} end)
    advance(%{game | hands: hands}, token, 1)
  end
```

- [ ] **Step 6: Run the tests to see them pass**

Run: `mix test test/lan_party/uno`
Expected: all tests pass, no compiler warnings.

---

### Task 7: Removing a kicked player, and "draw for player"

**Files:**
- Modify: `lib/lan_party/uno/rules.ex`
- Test: `test/lan_party/uno/rules_leave_test.exs`

**Interfaces:**
- Consumes: Task 4's `draw_cards/3`, `step/3`.
- Produces: `Rules.remove_player/2 :: game` and `Rules.draw_for/3 :: {:ok, game} | {:error, :not_in_game}`.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/uno/rules_leave_test.exs`:

```elixir
defmodule LanParty.Uno.RulesLeaveTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Uno.Rules

  describe "remove_player/2" do
    test "their cards go into the draw pile and play goes on" do
      game = Rules.remove_player(game(), "b")

      assert game.players == ["a", "c"]
      refute Map.has_key?(game.hands, "b")
      assert length(game.draw_pile) == 12
      assert game.current == "a"
    end

    test "if it was their turn, the turn passes" do
      assert Rules.remove_player(game(), "a").current == "b"
    end

    test "against the direction of play, the turn passes the other way" do
      assert Rules.remove_player(game(direction: -1), "a").current == "c"
    end

    test "a penalty aimed at them is dropped" do
      game = game(current: "b", pending: {:penalty, %{total: 4, top: :draw2, challenge: nil}})
      game = Rules.remove_player(game, "b")

      assert game.current == "c"
      assert game.pending == nil
    end

    test "if they had to pick the starting color, the next player picks it" do
      assert Rules.remove_player(game(pending: {:start_color, "a"}), "a").pending == {:start_color, "b"}
    end

    test "if they played the +4 being faced, the challenge goes away" do
      challenge = %{by: "a", legal: false, color: :red}
      game = game(current: "b", pending: {:penalty, %{total: 4, top: :draw4, challenge: challenge}})
      game = Rules.remove_player(game, "a")

      assert game.pending == {:penalty, %{total: 4, top: :draw4, challenge: nil}}
      assert game.current == "b"
    end

    test "removing someone who isn't in the round changes nothing" do
      assert Rules.remove_player(game(), "zed") == game()
    end
  end

  describe "draw_for/3" do
    test "the player draws n cards and nothing else changes" do
      game = game(current: "b", jump_in_open: true)
      {:ok, after_draw} = Rules.draw_for(game, "c", 3)

      assert length(after_draw.hands["c"]) == 5
      assert after_draw.current == "b"
      assert after_draw.pending == nil
      assert after_draw.jump_in_open
    end

    test "only players in the round" do
      assert Rules.draw_for(game(), "zed", 2) == {:error, :not_in_game}
    end

    test "when both piles run dry, they draw what there is" do
      game = game(draw_pile: [c(90, :green, 8), c(91, :green, 9)], discard: [c(100, :red, 5)])
      {:ok, game} = Rules.draw_for(game, "c", 10)

      assert length(game.hands["c"]) == 4
      assert game.draw_pile == []
    end
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/uno/rules_leave_test.exs`
Expected: FAIL, `function LanParty.Uno.Rules.remove_player/2 is undefined or private`.

- [ ] **Step 3: Implement both**

In `lib/lan_party/uno/rules.ex`, add a new section above `## Helpers`:

```elixir
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

  defp pending_after_leave({:start_color, _token}, next), do: {:start_color, next}
  defp pending_after_leave(_pending, _next), do: nil

  defp drop_challenge_by({:penalty, %{challenge: %{by: token}} = penalty}, token),
    do: {:penalty, %{penalty | challenge: nil}}

  defp drop_challenge_by(pending, _token), do: pending
```

- [ ] **Step 4: Run all rules tests**

Run: `mix test test/lan_party/uno`
Expected: all tests pass, no compiler warnings.

---

### Task 8: The game list and the Room (joining, picking, lobby, rounds)

**Files:**
- Create: `lib/lan_party/games.ex`, `lib/lan_party/room.ex`
- Modify: `lib/lan_party/application.ex` (start the Room)
- Test: `test/lan_party/games_test.exs`, `test/lan_party/room_test.exs`

**Interfaces:**
- Consumes: `Rules.default_settings/0`, `new/3`, `apply_action/3`, `draw_for/3`, `winner/1`.
- Produces:
  - `LanParty.Games.all/0 :: [%{id: atom, name: String.t(), playable?: boolean}]`,
    `Games.playable?/1`, `Games.name/1`.
  - `LanParty.Room` (registered as `LanParty.Room`; tests start their own with `name:`, `topic:`,
    `grace_ms:`, `game_opts:`). Every client function takes an optional first `server` argument:
    `get_state/0`, `join/3`, `attach/2`, `act/2`, `pick_game/1`, `change_game/0`,
    `update_settings/1`, `start_game/0`, `draw_for/2`, `back_to_lobby/0`, plus `subscribe/1`
    (topic, default `"party"`).
  - Broadcast `{:party_updated, state}` after every change. State keys: `topic, grace_ms, game_opts,
    game_id, phase, people, order, monitors, kicked, settings, game, winner`; person =
    `%{name, status: :seated | :queued, pids: MapSet, away_ref: nil | reference}`.
  - Pure readers for the LiveViews: `Room.seated/1`, `Room.queued/1`, `Room.away?/1` (person),
    `Room.name/2` (state, token → name or nil).
  - Errors: `:already_joined`, `:invalid_name`, `:name_taken`, `:not_playable`, `:not_now`,
    `:not_in_lobby`, `:not_enough_players`, `:not_playing`, `:unknown_player`, plus rules errors.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/games_test.exs`:

```elixir
defmodule LanParty.GamesTest do
  use ExUnit.Case, async: true

  alias LanParty.Games

  test "all 8 games from CLAUDE.md, in order; only UNO is playable" do
    assert Enum.map(Games.all(), & &1.name) ==
             ["UNO", "Liar's Dice", "Quiplash", "Paranoia", "Who wrote it?", "Love Letter", "Never Have I Ever", "Killer"]

    assert Games.playable?(:uno)
    refute Games.playable?(:quiplash)
    refute Games.playable?(:chess)
    assert Games.name(:uno) == "UNO"
  end
end
```

Create `test/lan_party/room_test.exs`:

```elixir
defmodule LanParty.RoomTest do
  use ExUnit.Case, async: true

  import LanParty.UnoHelpers

  alias LanParty.Room
  alias LanParty.Uno.{Card, Rules}

  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    topic = Atom.to_string(name)
    start_supervised!({Room, name: name, topic: topic, grace_ms: 50, game_opts: [deck: deck_starting_with(2, 5), first_player: "t1"]})
    Room.subscribe(topic)
    %{room: name}
  end

  # A stand-in for a LiveView page: a process that lives until killed.
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  defp join!(room, token, name), do: :ok = Room.join(room, token, name, page())

  describe "joining" do
    test "people join in arrival order and every page hears about it", %{room: room} do
      join!(room, "t1", "Alice")
      join!(room, "t2", "Bob")

      state = Room.get_state(room)
      assert state.order == ["t1", "t2"]
      assert Room.name(state, "t2") == "Bob"
      assert_receive {:party_updated, %{order: ["t1", "t2"]}}
    end

    test "names are trimmed, required, and at most 20 characters", %{room: room} do
      assert Room.join(room, "t1", "   ", page()) == {:error, :invalid_name}
      assert Room.join(room, "t1", String.duplicate("x", 21), page()) == {:error, :invalid_name}
      assert Room.join(room, "t1", "  Alice ", page()) == :ok
      assert Room.name(Room.get_state(room), "t1") == "Alice"
    end

    test "a name that differs only by case or spaces is taken", %{room: room} do
      join!(room, "t1", "Alice")
      assert Room.join(room, "t2", " alice ", page()) == {:error, :name_taken}
    end

    test "the same browser can't join twice", %{room: room} do
      join!(room, "t1", "Alice")
      assert Room.join(room, "t1", "Alicia", page()) == {:error, :already_joined}
    end
  end

  describe "picking a game" do
    test "only playable games, and only from the picker", %{room: room} do
      assert Room.get_state(room).phase == :picking
      assert Room.pick_game(room, :quiplash) == {:error, :not_playable}
      assert Room.pick_game(room, :uno) == :ok

      state = Room.get_state(room)
      assert state.game_id == :uno
      assert state.phase == :lobby
      assert Room.pick_game(room, :uno) == {:error, :not_now}
    end

    test "seats everyone in arrival order, up to 8; the rest queue", %{room: room} do
      for i <- 1..9, do: join!(room, "t#{i}", "P#{i}")
      :ok = Room.pick_game(room, :uno)

      state = Room.get_state(room)
      assert Room.seated(state) == Enum.map(1..8, &"t#{&1}")
      assert Room.queued(state) == ["t9"]
    end

    test "Change game goes back to the picker, from the lobby only", %{room: room} do
      assert Room.change_game(room) == {:error, :not_now}
      :ok = Room.pick_game(room, :uno)
      assert Room.change_game(room) == :ok

      state = Room.get_state(room)
      assert state.phase == :picking
      assert state.game_id == nil
    end
  end

  describe "the UNO lobby" do
    setup %{room: room} do
      :ok = Room.pick_game(room, :uno)
    end

    test "a 9th person waits in the queue", %{room: room} do
      for i <- 1..9, do: join!(room, "t#{i}", "P#{i}")
      assert Room.queued(Room.get_state(room)) == ["t9"]
    end

    test "settings accept only known house rules with true/false", %{room: room} do
      :ok = Room.update_settings(room, %{jump_in: true, stack_plus2: "yes", cheat: true})

      settings = Room.get_state(room).settings
      assert settings.jump_in
      refute settings.stack_plus2
      refute Map.has_key?(settings, :cheat)
    end

    test "starting needs 2 seated players", %{room: room} do
      join!(room, "t1", "Alice")
      assert Room.start_game(room) == {:error, :not_enough_players}
      join!(room, "t2", "Bob")
      assert Room.start_game(room) == :ok

      state = Room.get_state(room)
      assert state.phase == :playing
      assert state.game.players == ["t1", "t2"]
      assert Room.update_settings(room, %{jump_in: true}) == {:error, :not_in_lobby}
      assert Room.change_game(room) == {:error, :not_now}
    end

    test "someone joining mid-round is queued", %{room: room} do
      join!(room, "t1", "Alice")
      join!(room, "t2", "Bob")
      :ok = Room.start_game(room)
      join!(room, "t3", "Carol")

      assert Room.queued(Room.get_state(room)) == ["t3"]
    end
  end

  describe "a round" do
    # The fixed deck gives t1 red 0, 1, 2, 3, 4, 6, 7 (ids 1, 2, 3, 4, 5, 7, 8) and t2 ids 9–15;
    # red 5 (id 6) starts the pile and t1 goes first.
    setup %{room: room} do
      :ok = Room.pick_game(room, :uno)
      join!(room, "t1", "Alice")
      join!(room, "t2", "Bob")
      :ok = Room.start_game(room)
    end

    test "actions go to the rules; errors come back to the caller only", %{room: room} do
      assert Room.act(room, "t2", {:play, 9, %{}}) == {:error, :not_your_turn}
      assert Room.act(room, "t1", {:play, 2, %{}}) == :ok
      assert Rules.top_card(Room.get_state(room).game).id == 2
    end

    test "a win finishes the round", %{room: room} do
      :sys.replace_state(room, fn state ->
        put_in(state.game.hands["t1"], [%Card{id: 2, color: :red, value: 1}])
      end)

      assert Room.act(room, "t1", {:play, 2, %{}}) == :ok
      state = Room.get_state(room)
      assert state.phase == :finished
      assert state.winner == "t1"
    end

    test "draw for player takes 1 to 10 cards", %{room: room} do
      assert Room.draw_for(room, "t2", 0) == {:error, :not_now}
      assert Room.draw_for(room, "t2", 11) == {:error, :not_now}
      assert Room.draw_for(room, "t2", 2) == :ok
      assert length(Room.get_state(room).game.hands["t2"]) == 9
    end

    test "back to the lobby keeps seats, fills free ones from the queue, keeps settings", %{room: room} do
      join!(room, "t3", "Carol")
      assert Room.back_to_lobby(room) == :ok

      state = Room.get_state(room)
      assert state.phase == :lobby
      assert state.game == nil
      assert Room.seated(state) == ["t1", "t2", "t3"]
      assert Room.back_to_lobby(room) == {:error, :not_now}
    end

    test "actions outside a round are refused", %{room: room} do
      :ok = Room.back_to_lobby(room)
      assert Room.act(room, "t1", :draw) == {:error, :not_playing}
    end
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/games_test.exs test/lan_party/room_test.exs`
Expected: FAIL, `LanParty.Games.all/0 is undefined` and `LanParty.Room.child_spec/1 is undefined`.

- [ ] **Step 3: Implement `Games`**

Create `lib/lan_party/games.ex`:

```elixir
defmodule LanParty.Games do
  @moduledoc """
  The games on the table's "Select the game" screen (CLAUDE.md "Games"). Only UNO is built.
  A list, not a framework.
  """

  @games [
    %{id: :uno, name: "UNO", playable?: true},
    %{id: :liars_dice, name: "Liar's Dice", playable?: false},
    %{id: :quiplash, name: "Quiplash", playable?: false},
    %{id: :paranoia, name: "Paranoia", playable?: false},
    %{id: :who_wrote_it, name: "Who wrote it?", playable?: false},
    %{id: :love_letter, name: "Love Letter", playable?: false},
    %{id: :never_have_i_ever, name: "Never Have I Ever", playable?: false},
    %{id: :killer, name: "Killer", playable?: false}
  ]

  def all, do: @games

  def playable?(id), do: Enum.any?(@games, &(&1.id == id and &1.playable?))

  def name(id), do: Enum.find_value(@games, &(&1.id == id and &1.name))
end
```

- [ ] **Step 4: Implement the Room**

Create `lib/lan_party/room.ex`:

```elixir
defmodule LanParty.Room do
  @moduledoc """
  The platform state for the night: who has joined, the game the table picked, seats, queue, house
  rules, phases, disconnects and kicks. Knows nothing about cards: UNO actions go to
  `LanParty.Uno.Rules`. Calls are handled one at a time in arrival order, which is what makes
  "first jump-in wins" automatic. See uno/docs/design.md §4–5.
  """
  use GenServer

  alias LanParty.Games
  alias LanParty.Uno.Rules

  @max_seats 8
  @max_name 20
  @setting_keys Map.keys(Rules.default_settings())

  ## Client API. `server` defaults to the app-wide Room.

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def subscribe(topic \\ "party"), do: Phoenix.PubSub.subscribe(LanParty.PubSub, topic)

  def get_state(server \\ __MODULE__), do: GenServer.call(server, :get_state)

  def join(server \\ __MODULE__, token, name, pid) when is_binary(name),
    do: GenServer.call(server, {:join, token, name, pid})

  def attach(server \\ __MODULE__, token, pid), do: GenServer.call(server, {:attach, token, pid})
  def act(server \\ __MODULE__, token, action), do: GenServer.call(server, {:act, token, action})
  def pick_game(server \\ __MODULE__, game_id), do: GenServer.call(server, {:pick_game, game_id})
  def change_game(server \\ __MODULE__), do: GenServer.call(server, :change_game)

  def update_settings(server \\ __MODULE__, settings),
    do: GenServer.call(server, {:update_settings, settings})

  def start_game(server \\ __MODULE__), do: GenServer.call(server, :start_game)
  def draw_for(server \\ __MODULE__, token, n), do: GenServer.call(server, {:draw_for, token, n})
  def back_to_lobby(server \\ __MODULE__), do: GenServer.call(server, :back_to_lobby)

  ## Reading a state (pure helpers for the LiveViews)

  def seated(state), do: Enum.filter(state.order, &(state.people[&1].status == :seated))
  def queued(state), do: Enum.filter(state.order, &(state.people[&1].status == :queued))
  def away?(person), do: MapSet.size(person.pids) == 0
  def name(state, token), do: get_in(state, [:people, token, :name])

  ## Server

  @impl true
  def init(opts) do
    {:ok,
     %{
       topic: Keyword.get(opts, :topic, "party"),
       grace_ms: Keyword.get(opts, :grace_ms, Application.get_env(:lan_party, :grace_ms, 30_000)),
       game_opts: Keyword.get(opts, :game_opts, []),
       game_id: nil,
       phase: :picking,
       people: %{},
       order: [],
       monitors: %{},
       kicked: MapSet.new(),
       settings: Rules.default_settings(),
       game: nil,
       winner: nil
     }}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call({:join, token, name, pid}, _from, state) do
    name = String.trim(name)

    cond do
      Map.has_key?(state.people, token) ->
        {:reply, {:error, :already_joined}, state}

      name == "" or String.length(name) > @max_name ->
        {:reply, {:error, :invalid_name}, state}

      name_taken?(state, name) ->
        {:reply, {:error, :name_taken}, state}

      true ->
        person = %{name: name, status: join_status(state), pids: MapSet.new(), away_ref: nil}

        state =
          %{
            state
            | people: Map.put(state.people, token, person),
              order: state.order ++ [token],
              kicked: MapSet.delete(state.kicked, token)
          }
          |> watch(token, pid)

        {:reply, :ok, broadcast(state)}
    end
  end

  def handle_call({:attach, token, pid}, _from, state) do
    if Map.has_key?(state.people, token) do
      state = state |> watch(token, pid) |> update_person(token, &%{&1 | away_ref: nil})
      {:reply, :ok, broadcast(state)}
    else
      {:reply, {:error, :unknown_player}, state}
    end
  end

  def handle_call({:act, token, action}, _from, %{phase: :playing} = state) do
    case Rules.apply_action(state.game, token, action) do
      {:ok, game} -> {:reply, :ok, state |> put_game(game) |> broadcast()}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:act, _token, _action}, _from, state), do: {:reply, {:error, :not_playing}, state}

  def handle_call({:pick_game, game_id}, _from, %{phase: :picking} = state) do
    if Games.playable?(game_id),
      do: {:reply, :ok, %{state | game_id: game_id, phase: :lobby} |> reseat() |> broadcast()},
      else: {:reply, {:error, :not_playable}, state}
  end

  def handle_call({:pick_game, _game_id}, _from, state), do: {:reply, {:error, :not_now}, state}

  def handle_call(:change_game, _from, %{phase: :lobby} = state),
    do: {:reply, :ok, broadcast(%{state | game_id: nil, phase: :picking})}

  def handle_call(:change_game, _from, state), do: {:reply, {:error, :not_now}, state}

  def handle_call({:update_settings, settings}, _from, %{phase: :lobby} = state) do
    clean = for {key, value} <- settings, key in @setting_keys, is_boolean(value), into: %{}, do: {key, value}
    {:reply, :ok, broadcast(%{state | settings: Map.merge(state.settings, clean)})}
  end

  def handle_call({:update_settings, _settings}, _from, state), do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call(:start_game, _from, %{phase: :lobby} = state) do
    case seated(state) do
      [_, _ | _] = players ->
        game = Rules.new(players, state.settings, state.game_opts)
        {:reply, :ok, broadcast(%{state | phase: :playing, game: game, winner: nil})}

      _fewer ->
        {:reply, {:error, :not_enough_players}, state}
    end
  end

  def handle_call(:start_game, _from, state), do: {:reply, {:error, :not_in_lobby}, state}

  def handle_call({:draw_for, token, n}, _from, %{phase: :playing} = state)
      when is_integer(n) and n in 1..10 do
    case Rules.draw_for(state.game, token, n) do
      {:ok, game} -> {:reply, :ok, broadcast(%{state | game: game})}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  def handle_call({:draw_for, _token, _n}, _from, state), do: {:reply, {:error, :not_now}, state}

  def handle_call(:back_to_lobby, _from, %{phase: phase} = state) when phase in [:playing, :finished] do
    state = %{state | phase: :lobby, game: nil, winner: nil} |> fill_seats()
    {:reply, :ok, broadcast(state)}
  end

  def handle_call(:back_to_lobby, _from, state), do: {:reply, {:error, :not_now}, state}

  ## Helpers

  defp join_status(%{phase: :picking}), do: :seated
  defp join_status(%{phase: :lobby} = state), do: if(length(seated(state)) < @max_seats, do: :seated, else: :queued)
  defp join_status(_state), do: :queued

  defp name_taken?(state, name) do
    wanted = String.downcase(name)
    Enum.any?(state.people, fn {_token, person} -> String.downcase(person.name) == wanted end)
  end

  # Monitor a page so the Room hears when it closes (Task 9 handles that).
  defp watch(state, token, pid) do
    if MapSet.member?(state.people[token].pids, pid) do
      state
    else
      ref = Process.monitor(pid)

      state
      |> update_person(token, &%{&1 | pids: MapSet.put(&1.pids, pid)})
      |> Map.update!(:monitors, &Map.put(&1, ref, {token, pid}))
    end
  end

  defp put_game(state, game) do
    case Rules.winner(game) do
      nil -> %{state | game: game}
      winner -> %{state | game: game, phase: :finished, winner: winner}
    end
  end

  # Picking a game: everyone, in arrival order, up to 8 seats.
  defp reseat(state) do
    state.order
    |> Enum.with_index()
    |> Enum.reduce(state, fn {token, index}, acc ->
      update_person(acc, token, &%{&1 | status: if(index < @max_seats, do: :seated, else: :queued)})
    end)
  end

  # Back to the lobby: seated players keep their seats; queued players fill free ones.
  defp fill_seats(state) do
    free = max(@max_seats - length(seated(state)), 0)

    state
    |> queued()
    |> Enum.take(free)
    |> Enum.reduce(state, fn token, acc -> update_person(acc, token, &%{&1 | status: :seated}) end)
  end

  defp update_person(state, token, fun), do: %{state | people: Map.update!(state.people, token, fun)}

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(LanParty.PubSub, state.topic, {:party_updated, state})
    state
  end
end
```

- [ ] **Step 5: Start the Room with the app**

In `lib/lan_party/application.ex`, in the `children` list, add `LanParty.Room` directly **before**
`LanPartyWeb.Endpoint` (it needs `LanParty.PubSub`, which is earlier in the list).

- [ ] **Step 6: Run the tests to see them pass**

Run: `mix test`
Expected: all tests pass. (The Room logs nothing when a monitored test page dies; Task 9 adds the
handler. If you see "received unexpected message in handle_info/2" warnings, they go away in Task 9.)

---

### Task 9: Disconnects, the grace period, kicks

**Files:**
- Modify: `lib/lan_party/room.ex`
- Test: `test/lan_party/room_disconnect_test.exs`

**Interfaces:**
- Consumes: Task 8's `watch/3` monitors and `state.monitors`; `Rules.remove_player/2`.
- Produces: a person whose last page closed is *away* (`Room.away?/1`); after `grace_ms` without a page
  they're removed from `people` and `order`, added to `kicked`, and taken out of a running round. If
  one player is left in a round, the phase becomes `:finished` with them as the winner.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party/room_disconnect_test.exs`:

```elixir
defmodule LanParty.RoomDisconnectTest do
  use ExUnit.Case, async: true

  alias LanParty.Room

  setup do
    name = :"room_#{System.unique_integer([:positive])}"
    start_supervised!({Room, name: name, topic: Atom.to_string(name), grace_ms: 50})
    %{room: name}
  end

  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  # Close a page and give the Room a moment to notice.
  defp close(pid) do
    Process.exit(pid, :kill)
    Process.sleep(10)
  end

  defp person(room, token), do: Room.get_state(room).people[token]

  test "a closed page marks the player away; after the grace period they're kicked", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    close(tab)

    assert Room.away?(person(room, "t1"))

    Process.sleep(80)
    state = Room.get_state(room)
    refute Map.has_key?(state.people, "t1")
    assert state.order == []
    assert MapSet.member?(state.kicked, "t1")
  end

  test "coming back within the grace period keeps the seat", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    close(tab)
    :ok = Room.attach(room, "t1", page())

    Process.sleep(80)
    refute Room.away?(person(room, "t1"))
  end

  test "closing one of two tabs doesn't make you away", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    :ok = Room.attach(room, "t1", page())
    close(tab)

    Process.sleep(80)
    refute Room.away?(person(room, "t1"))
  end

  test "a kicked player who joins again is no longer marked as kicked", %{room: room} do
    tab = page()
    :ok = Room.join(room, "t1", "Alice", tab)
    close(tab)
    Process.sleep(80)

    :ok = Room.join(room, "t1", "Alice", page())
    refute MapSet.member?(Room.get_state(room).kicked, "t1")
  end

  test "attaching a browser the Room doesn't know fails", %{room: room} do
    assert Room.attach(room, "nobody", page()) == {:error, :unknown_player}
  end

  describe "during a round" do
    setup %{room: room} do
      tabs = %{"t1" => page(), "t2" => page(), "t3" => page()}
      for token <- ["t1", "t2", "t3"], do: :ok = Room.join(room, token, token, tabs[token])
      :ok = Room.pick_game(room, :uno)
      :ok = Room.start_game(room)
      %{tabs: tabs}
    end

    test "a kicked player leaves the round and play goes on", %{room: room, tabs: tabs} do
      close(tabs["t3"])
      Process.sleep(80)

      state = Room.get_state(room)
      assert state.phase == :playing
      assert state.game.players == ["t1", "t2"]
    end

    test "when one player is left, they win", %{room: room, tabs: tabs} do
      close(tabs["t2"])
      close(tabs["t3"])
      Process.sleep(80)

      state = Room.get_state(room)
      assert state.phase == :finished
      assert state.winner == "t1"
    end
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party/room_disconnect_test.exs`
Expected: FAIL. `away?` is false after closing (no handler yet) and nobody is kicked.

- [ ] **Step 3: Handle closed pages and the grace timer**

In `lib/lan_party/room.ex`, add these callbacks directly after the last `handle_call/3` clause:

```elixir
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, _monitors} -> {:noreply, state}
      {{token, pid}, monitors} -> {:noreply, page_closed(%{state | monitors: monitors}, token, pid)}
    end
  end

  # Only the newest timer counts: coming back clears `away_ref`, so an old timer is ignored.
  def handle_info({:grace_expired, token, ref}, state) do
    case state.people[token] do
      %{away_ref: ^ref} -> {:noreply, state |> kick(token) |> broadcast()}
      _other -> {:noreply, state}
    end
  end
```

Add these helpers in the `## Helpers` section:

```elixir
  defp page_closed(state, token, pid) do
    case state.people[token] do
      nil ->
        state

      person ->
        pids = MapSet.delete(person.pids, pid)

        if MapSet.size(pids) == 0 do
          ref = make_ref()
          Process.send_after(self(), {:grace_expired, token, ref}, state.grace_ms)
          state |> update_person(token, &%{&1 | pids: pids, away_ref: ref}) |> broadcast()
        else
          update_person(state, token, &%{&1 | pids: pids})
        end
    end
  end

  # Forgotten for the night. If they were in a round, the rules take them out of it.
  defp kick(state, token) do
    person = state.people[token]

    state = %{
      state
      | people: Map.delete(state.people, token),
        order: List.delete(state.order, token),
        kicked: MapSet.put(state.kicked, token)
    }

    if state.phase == :playing and person.status == :seated,
      do: remove_from_round(state, token),
      else: state
  end

  # Last player left wins (CLAUDE.md "Disconnects").
  defp remove_from_round(state, token) do
    game = Rules.remove_player(state.game, token)

    case game.players do
      [last] -> %{state | game: game, phase: :finished, winner: last}
      _more -> %{state | game: game}
    end
  end
```

- [ ] **Step 4: Run all tests**

Run: `mix test`
Expected: all tests pass.

---

### Task 10: Web shell — the mockup styles, player identity, joining, and "Select the game"

**Files:**
- Replace: `assets/css/app.css` (with a copy of `mockups/style.css`),
  `lib/lan_party_web/components/layouts/root.html.heex`
- Modify: `lib/lan_party_web/endpoint.ex`, `lib/lan_party_web/router.ex`
- Delete: `lib/lan_party_web/controllers/page_controller.ex`, `lib/lan_party_web/controllers/page_html.ex`,
  `lib/lan_party_web/controllers/page_html/`, `test/lan_party_web/controllers/page_controller_test.exs`
- Create: `lib/lan_party_web/plugs/player_token.ex`, `lib/lan_party_web/live/uno/components.ex`,
  `lib/lan_party_web/live/player_live.ex`, `lib/lan_party_web/live/table_live.ex`
- Test: `test/lan_party_web/plugs/player_token_test.exs`, `test/lan_party_web/live/player_live_test.exs`,
  `test/lan_party_web/live/table_live_test.exs`

**Interfaces:**
- Consumes: `Room` (Tasks 8–9), `Games` (Task 8), `Card` (Task 2), `UnoHelpers.restart_room/0`.
- Produces:
  - Session key `"player_token"` (a random string) on every browser request.
  - `LanPartyWeb.Uno.Components`: `card/1` (attrs `card`, plus global attrs such as `style`) renders
    a mockup card as `<span class="card …" role="img">`; `card_button/1` (attrs `card`, plus global
    `phx-*` attrs) renders a tappable `<a class="card …">`; `toast/1` (attr `message`, plus global
    attrs) renders `<a class="toast" role="alert">…<span>OK</span></a>`.
  - `PlayerLive` at `/` with assigns `token`, `room`, `me`, `brand`, `glow`, `kicked?`, `error`,
    `name`. Task 11 adds the UNO component where the template says so.
  - `TableLive` at `/table` with assigns `room`, `main_class`. Task 12 adds the UNO component.
  - Event `"pick_game"` with `%{"id" => "uno"}` on the table.

- [ ] **Step 1: Use the mockup stylesheet and fonts**

Copy `mockups/style.css` over `assets/css/app.css` (replace the whole file, including the generated
Tailwind/daisyUI lines; the app uses only the mockup CSS):

Run (PowerShell): `Copy-Item mockups/style.css assets/css/app.css -Force`

Replace `lib/lan_party_web/components/layouts/root.html.heex` with the following. Keep the two
generated asset tags exactly as your generator wrote them if the paths differ (Phoenix 1.7 uses
`/assets/app.css` and `/assets/app.js`). The SVG sprite holds the Skip, Reverse and direction
symbols the card faces use (copied from the mockups).

```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title>{assigns[:page_title] || "LAN Party"}</.live_title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Rubik:ital,wght@0,400;0,500;0,700;0,800;1,800;1,900&display=swap"
      rel="stylesheet"
    />
    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
    <%!-- iOS Safari only delivers taps on elements it thinks are clickable, and LiveView listens for
         clicks on window: without this, tapping an <a phx-click> with no href may do nothing on an
         iPhone. Kept here so app.css stays an exact copy of mockups/style.css. --%>
    <style>[phx-click] { cursor: pointer; }</style>
    <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
    </script>
  </head>
  <body>
    <svg width="0" height="0" style="position:absolute" aria-hidden="true">
      <symbol id="skip" viewBox="0 0 100 100">
        <g fill="none" stroke-linecap="round">
          <circle cx="50" cy="50" r="31" stroke="#000" stroke-width="23" />
          <line x1="29" y1="71" x2="71" y2="29" stroke="#000" stroke-width="23" />
          <circle cx="50" cy="50" r="31" stroke="currentColor" stroke-width="13" />
          <line x1="29" y1="71" x2="71" y2="29" stroke="currentColor" stroke-width="13" />
        </g>
      </symbol>
      <symbol id="reverse" viewBox="0 0 100 100">
        <g
          transform="rotate(-45 50 50)"
          fill="currentColor"
          stroke="#000"
          stroke-width="6"
          stroke-linejoin="round"
          paint-order="stroke"
        >
          <polygon points="14,27 56,27 56,15 84,34 56,53 56,41 14,41" />
          <polygon points="86,59 44,59 44,47 16,66 44,85 44,73 86,73" />
        </g>
      </symbol>
      <symbol id="clockwise" viewBox="0 0 100 100">
        <path
          d="M50 20 A32 32 0 1 1 22.3 36"
          fill="none"
          stroke="currentColor"
          stroke-width="10"
          stroke-linecap="round"
        />
        <polygon points="27.3,27.4 29.8,45 10.8,34" fill="currentColor" />
      </symbol>
    </svg>
    {@inner_content}
  </body>
</html>
```

If `lib/lan_party_web.ex`'s `live_view` function passes `layout: {LanPartyWeb.Layouts, :app}`
(Phoenix 1.7), remove that option so pages render only the root layout.

- [ ] **Step 2: Write the failing plug test**

Create `test/lan_party_web/plugs/player_token_test.exs`:

```elixir
defmodule LanPartyWeb.Plugs.PlayerTokenTest do
  use LanPartyWeb.ConnCase, async: true

  alias LanPartyWeb.Plugs.PlayerToken

  test "a new browser gets a random token" do
    conn = build_conn() |> Plug.Test.init_test_session(%{}) |> PlayerToken.call([])
    token = get_session(conn, "player_token")

    assert is_binary(token)
    assert byte_size(token) >= 20
  end

  test "a browser that has a token keeps it" do
    conn = build_conn() |> Plug.Test.init_test_session(%{"player_token" => "keep-me"}) |> PlayerToken.call([])
    assert get_session(conn, "player_token") == "keep-me"
  end
end
```

Run: `mix test test/lan_party_web/plugs/player_token_test.exs`
Expected: FAIL, `LanPartyWeb.Plugs.PlayerToken.call/2 is undefined`.

- [ ] **Step 3: Implement the plug, the session lifetime, and the routes**

Create `lib/lan_party_web/plugs/player_token.ex`:

```elixir
defmodule LanPartyWeb.Plugs.PlayerToken do
  @moduledoc """
  Gives each browser a random player token in the signed session cookie. The token is the player's
  identity: "reconnecting" means a page comes back with a token the Room knows (design.md §4).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, "player_token") do
      nil -> put_session(conn, "player_token", Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false))
      _token -> conn
    end
  end
end
```

In `lib/lan_party_web/endpoint.ex`, add `max_age: 86_400` (one day) to `@session_options`, e.g.:

```elixir
  @session_options [
    store: :cookie,
    key: "_lan_party_key",
    signing_salt: "…keep the generated value…",
    same_site: "Lax",
    max_age: 86_400
  ]
```

In `lib/lan_party_web/router.ex`, add `plug LanPartyWeb.Plugs.PlayerToken` as the last plug of the
`:browser` pipeline. (The routes change in Step 9, once the LiveViews exist.)

Run: `mix test test/lan_party_web/plugs/player_token_test.exs`
Expected: PASS.

- [ ] **Step 4: Write the failing LiveView tests**

Create `test/lan_party_web/live/player_live_test.exs`:

```elixir
defmodule LanPartyWeb.PlayerLiveTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room

  setup do
    restart_room()
  end

  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  test "a new phone sees the join screen", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    assert has_element?(view, "form#join input[name=name]")
    assert has_element?(view, ".brand", "LAN Party")
  end

  test "joining shows who is here while the table picks a game", %{conn: conn} do
    :ok = Room.join("alice", "Alice", page())
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    view |> form("#join", %{name: "Erin"}) |> render_submit()

    assert has_element?(view, ".wait", "Waiting for the table to pick a game")
    assert has_element?(view, ".people li.you", "Erin (you)")
    assert has_element?(view, ".people li", "Alice")
    assert has_element?(view, ".bar strong", "Erin")
  end

  test "a taken name is refused", %{conn: conn} do
    :ok = Room.join("alice", "Alice", page())
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    view |> form("#join", %{name: " alice"}) |> render_submit()

    assert has_element?(view, ".field-error", "That name is taken. Try another.")
  end

  test "a joined phone that reloads skips the join screen", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")
    view |> form("#join", %{name: "Erin"}) |> render_submit()

    {:ok, again, _html} = live(phone(build_conn(), "erin"), ~p"/")
    refute has_element?(again, "form#join")
    assert has_element?(again, ".wait", "Waiting for the table to pick a game")
  end

  test "a kicked phone is told why", %{conn: conn} do
    :sys.replace_state(Room, fn state -> %{state | kicked: MapSet.put(state.kicked, "erin")} end)
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")

    assert has_element?(view, ".notice", "You were away too long and left the game.")
  end

  test "when the Room restarts, the phone reloads", %{conn: conn} do
    {:ok, view, _html} = live(phone(conn, "erin"), ~p"/")
    Process.exit(Process.whereis(Room), :kill)

    assert_redirect(view, ~p"/")
  end
end
```

Create `test/lan_party_web/live/table_live_test.exs`:

```elixir
defmodule LanPartyWeb.TableLiveTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room

  setup do
    restart_room()
  end

  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  test "the table starts on Select the game, listing every game and who has joined", %{conn: conn} do
    :ok = Room.join("erin", "Erin", page())
    {:ok, view, _html} = live(conn, ~p"/table")

    assert has_element?(view, "h1", "Select the game")
    assert has_element?(view, ".joined", "Joined so far: Erin")

    for name <- ["Quiplash", "Paranoia", "Who wrote it?", "Love Letter", "Never Have I Ever", "Killer"] do
      assert has_element?(view, ".spine b", name)
    end

    assert has_element?(view, ".spine small", "Not built yet")
  end

  test "picking UNO switches every phone to UNO", %{conn: conn} do
    {:ok, phone, _html} = live(Plug.Test.init_test_session(conn, %{"player_token" => "erin"}), ~p"/")
    phone |> form("#join", %{name: "Erin"}) |> render_submit()

    {:ok, table, _html} = live(build_conn(), ~p"/table")
    table |> element(".shelf-aside button", "Play UNO") |> render_click()

    assert Room.get_state().game_id == :uno
    assert has_element?(phone, ".brand", "UNO")
  end

  test "a game that isn't built can't be picked", %{conn: conn} do
    {:ok, table, _html} = live(conn, ~p"/table")
    render_click(table, "pick_game", %{"id" => "quiplash"})

    assert Room.get_state().game_id == nil
  end
end
```

- [ ] **Step 5: Run them to see them fail**

Run: `mix test test/lan_party_web/live`
Expected: FAIL. `/` is still the generated page and `/table` doesn't exist, so `live/2` can't mount.

- [ ] **Step 6: Implement the shared card components**

Create `lib/lan_party_web/live/uno/components.ex`. The markup is the mockups' card markup
(`mockups/phone/turn-mine.html`), one face per kind of card:

```elixir
defmodule LanPartyWeb.Uno.Components do
  @moduledoc "UNO pieces shared by the phone and table screens. Markup copied from mockups/."
  use Phoenix.Component

  alias LanParty.Uno.Card

  @doc "A card to look at (the pile, a result screen)."
  attr :card, Card, required: true
  attr :rest, :global

  def card(assigns) do
    ~H"""
    <span class={["card", color_class(@card)]} role="img" aria-label={aria_label(@card)} {@rest}>
      <.face card={@card} />
    </span>
    """
  end

  @doc "A card in your hand that you can tap."
  attr :card, Card, required: true
  attr :rest, :global

  def card_button(assigns) do
    ~H"""
    <a class={["card", color_class(@card)]} role="button" aria-label={aria_label(@card)} {@rest}>
      <.face card={@card} />
    </a>
    """
  end

  @doc "A message with an OK to dismiss it."
  attr :message, :string, required: true
  attr :rest, :global

  def toast(assigns) do
    ~H"""
    <a class="toast" role="alert" {@rest}><span>{@message}</span><span>OK</span></a>
    """
  end

  def color_class(%Card{color: nil}), do: "black"
  def color_class(%Card{color: color}), do: Atom.to_string(color)

  def aria_label(card), do: String.capitalize(Card.label(card))

  defp face(%{card: %Card{value: :wild}} = assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval quad"></span><span class="idx"><span class="dot4"></span></span><span class="idx br"><span class="dot4"></span></span></span>
    """
  end

  defp face(%{card: %Card{value: :wild_draw4}} = assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class="mini" style="--mc:var(--yellow);--dx:calc(var(--cw)*-0.14);--dy:calc(var(--cw)*0.11)"></span><span class="mini" style="--mc:var(--green);--dx:calc(var(--cw)*-0.05);--dy:calc(var(--cw)*0.04)"></span><span class="mini" style="--mc:var(--blue);--dx:calc(var(--cw)*0.04);--dy:calc(var(--cw)*-0.03)"></span><span class="mini" style="--mc:var(--red);--dx:calc(var(--cw)*0.13);--dy:calc(var(--cw)*-0.1)"></span><span class="idx">+4</span><span class="idx br">+4</span></span>
    """
  end

  defp face(%{card: %Card{value: :draw2}} = assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class="mini" style="--dx:calc(var(--cw)*-0.06);--dy:calc(var(--cw)*0.06)"></span><span class="mini" style="--dx:calc(var(--cw)*0.06);--dy:calc(var(--cw)*-0.06)"></span><span class="idx">+2</span><span class="idx br">+2</span></span>
    """
  end

  defp face(%{card: %Card{value: symbol}} = assigns) when symbol in [:skip, :reverse] do
    assigns = assign(assigns, :href, "##{symbol}")

    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class="big"><svg><use href={@href} /></svg></span><span class="idx"><svg><use href={@href} /></svg></span><span class="idx br"><svg><use href={@href} /></svg></span></span>
    """
  end

  defp face(assigns) do
    ~H"""
    <span class="face" aria-hidden="true"><span class="oval"></span><span class={["big", @card.value in [6, 9] && "u"]}><span>{@card.value}</span></span><span class="idx">{@card.value}</span><span class="idx br">{@card.value}</span></span>
    """
  end
end
```

- [ ] **Step 7: Implement `PlayerLive`**

Create `lib/lan_party_web/live/player_live.ex` (markup from `mockups/phone/index.html`,
`join-taken.html`, `join-kicked.html`, `waiting-game.html`, `reconnecting.html`):

```elixir
defmodule LanPartyWeb.PlayerLive do
  @moduledoc """
  The phone at `/`: join once per night, wait for the table to pick a game, then that game's phone
  screens. See uno/docs/design.md §2 and §4. Markup follows mockups/phone/.
  """
  use LanPartyWeb, :live_view

  alias LanParty.{Games, Room}

  @impl true
  def mount(_params, %{"player_token" => token}, socket) do
    if connected?(socket) do
      Room.subscribe()
      Process.monitor(Room)
      Room.attach(token, self())
    end

    {:ok, socket |> assign(token: token, error: nil, name: "") |> assign_room(Room.get_state())}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    case Room.join(socket.assigns.token, name, self()) do
      :ok -> {:noreply, assign(socket, error: nil)}
      {:error, :already_joined} -> {:noreply, socket}
      {:error, :name_taken} -> {:noreply, assign(socket, error: "That name is taken. Try another.", name: name)}
      {:error, _reason} -> {:noreply, assign(socket, error: "Enter a name of up to 20 characters.", name: name)}
    end
  end

  @impl true
  def handle_info({:party_updated, room}, socket), do: {:noreply, assign_room(socket, room)}

  # The Room crashed and restarted empty: reload so this phone lands on the join screen.
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, redirect(socket, to: ~p"/")}

  defp assign_room(socket, room) do
    me = room.people[socket.assigns.token]

    assign(socket,
      room: room,
      me: me,
      kicked?: MapSet.member?(room.kicked, socket.assigns.token),
      brand: if(me && room.game_id, do: Games.name(room.game_id), else: "LAN Party"),
      glow: nil
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class={["phone", @glow]}>
      <header class="bar">
        <span :if={@me}>Playing as <strong>{@me.name}</strong></span>
        <span :if={!@me}></span>
        <span class="brand">{@brand}</span>
      </header>

      <div :if={!@me} class="message">
        <p :if={@kicked?} class="notice">
          You were away too long and left the game. Join again for the next game.
        </p>
        <form class="join" id="join" phx-submit="join">
          <label for="name">What's your name?</label>
          <input
            class="field"
            id="name"
            name="name"
            autocomplete="nickname"
            maxlength="20"
            placeholder="Your name"
            value={@name}
            aria-invalid={@error && "true"}
            aria-describedby={@error && "name-error"}
          />
          <p :if={@error} class="field-error" id="name-error">{@error}</p>
          <button class="btn btn-primary" type="submit">Join</button>
        </form>
      </div>

      <div :if={@me && is_nil(@room.game_id)} class="message">
        <h1>You're in, {@me.name}.</h1>
        <p class="wait">Waiting for the table to pick a game</p>
        <div>
          <p class="people-label">Here now</p>
          <ul class="people">
            <li :for={token <- @room.order} class={token == @token && "you"}>
              {Room.name(@room, token)}{if token == @token, do: " (you)"}
            </li>
          </ul>
        </div>
      </div>

      <%!-- GAME SCREENS: Task 11 renders the UNO component here. --%>

      <div
        id="reconnect"
        style="display: none"
        phx-disconnected={JS.show(to: "#reconnect")}
        phx-connected={JS.hide(to: "#reconnect")}
      >
        <div class="scrim"></div>
        <div class="reconnect" role="status">
          <strong>Reconnecting…</strong><span>Your phone lost the connection. Keep this page open.</span>
        </div>
      </div>
    </main>
    """
  end
end
```

- [ ] **Step 8: Implement `TableLive` with "Select the game"**

Create `lib/lan_party_web/live/table_live.ex` (markup from `mockups/table/index.html`; the spine colors
and sizes are copied from it):

```elixir
defmodule LanPartyWeb.TableLive do
  @moduledoc """
  The table at `/table`: "Select the game", then that game's table screens. Any number of table
  devices can be open; all show the same thing and all can use the controls.
  Markup follows mockups/table/.
  """
  use LanPartyWeb, :live_view

  alias LanParty.{Games, Room}
  alias LanParty.Uno.Card
  import LanPartyWeb.Uno.Components

  @spines %{
    liars_dice: "--sc:#8a3340;--h:84%;--w:max(46px,5.2vw)",
    quiplash: "--sc:#2f7a7e;--h:92%;--w:max(46px,4.4vw)",
    paranoia: "--sc:#63428a;--h:76%;--w:max(46px,4.8vw)",
    who_wrote_it: "--sc:#96742c;--h:88%;--w:max(46px,4.2vw)",
    love_letter: "--sc:#9a4466;--h:74%;--w:max(46px,4.4vw)",
    never_have_i_ever: "--sc:#3f5590;--h:96%;--w:max(46px,5.6vw)",
    killer: "--sc:#355a45;--h:80%;--w:max(46px,4.4vw)"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Room.subscribe()
      Process.monitor(Room)
    end

    {:ok, assign_room(socket, Room.get_state())}
  end

  @impl true
  def handle_event("pick_game", %{"id" => id}, socket) do
    case Enum.find(Games.all(), &(Atom.to_string(&1.id) == id)) do
      %{id: game_id} -> Room.pick_game(game_id)
      nil -> :ignore
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_updated, room}, socket), do: {:noreply, assign_room(socket, room)}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, redirect(socket, to: ~p"/table")}

  defp assign_room(socket, room) do
    assign(socket,
      room: room,
      main_class: if(is_nil(room.game_id), do: "tv shelf-room", else: "tv"),
      unbuilt: Enum.reject(Games.all(), & &1.playable?),
      spines: @spines
    )
  end

  defp joined(%{order: []}), do: "Nobody has joined yet."
  defp joined(room), do: "Joined so far: " <> Enum.map_join(room.order, ", ", &Room.name(room, &1))

  @impl true
  def render(assigns) do
    ~H"""
    <main class={@main_class}>
      <%= if is_nil(@room.game_id) do %>
        <header class="tv-head"><span class="brand">LAN Party</span></header>
        <div>
          <h1>Select the game</h1>
          <p class="joined">{joined(@room)}</p>
        </div>
        <section class="shelf" aria-label="Games">
          <div class="shelf-row">
            <a class="box-uno" phx-click="pick_game" phx-value-id="uno" aria-label="UNO, 2 to 8 players">
              <span class="box-logo" aria-hidden="true">UNO</span>
              <span class="box-fan" aria-hidden="true">
                <.card card={%Card{id: 0, color: :red, value: 7}} style="--r:-16deg;--x:-42%" />
                <.card card={%Card{id: 0, color: :yellow, value: :reverse}} style="--r:0deg;--x:0%" />
                <.card card={%Card{id: 0, color: nil, value: :wild}} style="--r:16deg;--x:42%" />
              </span>
              <span class="box-tag">2 to 8 players</span>
            </a>
            <div :for={game <- @unbuilt} class="spine" style={@spines[game.id]}>
              <b>{game.name}</b><small>Not built yet</small>
            </div>
            <div class="shelf-aside">
              <h2>UNO</h2>
              <p>The card game. Match the color or the number, and be the first to empty your hand.</p>
              <button class="btn btn-primary btn-big" phx-click="pick_game" phx-value-id="uno">Play UNO</button>
            </div>
          </div>
          <div class="plank"></div>
        </section>
      <% end %>

      <%!-- GAME SCREENS: Task 12 renders the UNO component here. --%>
    </main>
    """
  end
end
```

- [ ] **Step 9: Route `/` and `/table` to the LiveViews**

In `lib/lan_party_web/router.ex`, replace the `get "/", PageController, :home` line with:

```elixir
    live "/", PlayerLive
    live "/table", TableLive
```

Delete the generated page controller files listed at the top of this task (nothing routes to them
any more).

Run: `mix test test/lan_party_web`
Expected: all pass.

- [ ] **Step 10: Compare against the mockups in a browser**

Run: `mix phx.server`, open `http://localhost:4000/` and `http://localhost:4000/table` next to
`mockups/phone/index.html`, `mockups/phone/waiting-game.html` and `mockups/table/index.html` (open the
mockup files directly in the browser). Use the browser's phone emulation for `/`. They should look the
same apart from names. If the mockup files changed since this plan was written, align the markup and
copy with them now.

---

### Task 11: UNO on the phone

**Files:**
- Create: `lib/lan_party_web/live/uno/player_component.ex`
- Modify: `lib/lan_party_web/live/player_live.ex`
- Test: `test/lan_party_web/live/uno_phone_test.exs`

**Interfaces:**
- Consumes: `View.player_view/2` (Tasks 3, 5), `Room` actions and readers, `Uno.Components`.
- Produces: `LanPartyWeb.Uno.PlayerComponent` (LiveComponent, id `"uno-phone"`, assigns `room`,
  `token`) and `PlayerComponent.glow/2 :: String.t() | nil` for the phone's `<main>`.

Screens and copy come from these mockups: `lobby.html`, `queue.html`, `turn-mine.html`,
`turn-alice.html`, `no-match.html`, `not-your-turn.html`, `pick-color.html`, `pick-swap.html`,
`start-color.html`, `drew-card.html`, `penalty.html`, `penalty-resolve.html`, `stack-color.html`,
`challenge-lost.html`, `won.html`, `lost.html`. Differences on purpose:
- Hand cards are always tappable `<a>` elements (the mockups use `<span>` when it's not your turn),
  because jump-in lets you play out of turn. The server still answers "Not your turn".
- The challenge message names the color **before** the +4 (the one that decides whether the +4 was
  fair). `challenge-lost.html` shows the chosen color, which is the wrong one.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party_web/live/uno_phone_test.exs`:

```elixir
defmodule LanPartyWeb.UnoPhoneTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room
  alias LanParty.Uno.Rules

  # Erin (this phone) and Bob. With the fixed deck Erin holds red 0, 1, 2, 3, 4, 6, 7
  # (ids 1, 2, 3, 4, 5, 7, 8), Bob holds ids 9–15, red 5 starts the pile, and Erin goes first.
  setup %{conn: conn} do
    restart_room()
    use_deck(deck_starting_with(2, 5))
    {:ok, erin, _html} = live(phone(conn, "erin"), ~p"/")
    erin |> form("#join", %{name: "Erin"}) |> render_submit()
    :ok = Room.join("bob", "Bob", page())
    :ok = Room.pick_game(:uno)
    %{erin: erin}
  end

  defp phone(conn, token), do: Plug.Test.init_test_session(conn, %{"player_token" => token})
  defp page, do: spawn(fn -> Process.sleep(:infinity) end)
  defp use_deck(deck), do: :sys.replace_state(Room, &%{&1 | game_opts: [deck: deck, first_player: "erin"]})
  defp start!, do: :ok = Room.start_game()
  defp tap(view, id), do: view |> element(~s(.hand a.card[phx-value-id="#{id}"])) |> render_click()

  # Change the running game behind the scenes, then let the phone re-render.
  defp tweak_game(view, fun) do
    :sys.replace_state(Room, fn state -> %{state | game: fun.(state.game)} end)
    send(view.pid, {:party_updated, Room.get_state()})
    view
  end

  defp facing_plus4(game) do
    challenge = %{by: "bob", legal: true, color: :red}

    %{
      game
      | pending: {:penalty, %{total: 4, top: :draw4, challenge: challenge}},
        last_played_by: "bob",
        discard: [c(500, nil, :wild_draw4) | game.discard],
        color: :green
    }
  end

  test "the lobby lists the players", %{erin: erin} do
    assert has_element?(erin, ".brand", "UNO")
    assert has_element?(erin, ".wait", "Waiting for the table to start")
    assert has_element?(erin, ".people li.you", "Erin (you)")
    assert has_element?(erin, ".people li", "Bob")
  end

  test "a phone shows only its own hand, never the pile or the color", %{erin: erin} do
    start!()

    for id <- [1, 2, 3, 4, 5, 7, 8], do: assert(has_element?(erin, ~s(.hand a.card[phx-value-id="#{id}"])))
    for id <- 9..15, do: refute(has_element?(erin, ~s(.hand a.card[phx-value-id="#{id}"])))
    refute has_element?(erin, ".pile")
    refute render(erin) =~ "Color:"
    assert has_element?(erin, ".your-turn", "Your turn")
    assert has_element?(erin, ".stage-hint", "Match the top card on the table.")
    assert has_element?(erin, "main.glow-turn")
  end

  test "tapping a card plays it", %{erin: erin} do
    start!()
    tap(erin, 2)

    assert Rules.top_card(Room.get_state().game).id == 2
    assert has_element?(erin, ".turn", "Bob's turn")
    refute has_element?(erin, "main.glow-turn")
  end

  test "a card out of turn gets Not your turn; OK hides it", %{erin: erin} do
    start!()
    tap(erin, 2)
    tap(erin, 3)

    assert has_element?(erin, ".toast", "Not your turn")
    erin |> element(".toast") |> render_click()
    refute has_element?(erin, ".toast")
  end

  test "a card that doesn't match names the top card", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> put_in(game.hands["erin"], [c(50, :blue, 9), c(2, :red, 1)]) end)
    tap(erin, 50)

    assert has_element?(erin, ".toast", "Doesn't match: red 5")
  end

  test "a Wild asks for a color first; only the four colors count", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> put_in(game.hands["erin"], [c(60, nil, :wild), c(2, :red, 1)]) end)
    tap(erin, 60)
    assert has_element?(erin, ".sheet h2", "Pick a color")

    render_click(with_target(erin, "#uno-phone"), "pick_color", %{"color" => "purple"})
    assert has_element?(erin, ".sheet h2", "Pick a color")

    erin |> element(".swatch.green") |> render_click()
    assert Room.get_state().game.color == :green
    refute has_element?(erin, ".sheet")
  end

  test "a 7 under 7-0 asks who to swap with", %{erin: erin} do
    :ok = Room.update_settings(%{seven_zero: true})
    start!()
    tap(erin, 8)

    assert has_element?(erin, ".sheet h2", "Swap hands with…")
    erin |> element(".pick-list a", "Bob") |> render_click()
    assert ids(Room.get_state().game.hands["erin"]) == Enum.to_list(9..15)
  end

  test "a +4 aimed at you says who played it and offers Draw 4 and Challenge", %{erin: erin} do
    start!()
    tweak_game(erin, &facing_plus4/1)

    assert has_element?(erin, ".threat", "+4")
    assert has_element?(erin, ".threat-sub", "Bob played it.")
    assert has_element?(erin, ".actions button", "Draw 4")

    erin |> element(".actions button", "Challenge") |> render_click()
    assert has_element?(erin, ".toast", "Bob had no red card, so the +4 was fair. You drew 6.")
  end

  test "with stacking on, the phone says how to get out of a penalty", %{erin: erin} do
    :ok = Room.update_settings(%{stack_plus4: true})
    start!()
    tweak_game(erin, &facing_plus4/1)

    assert has_element?(erin, ".hint", "Or tap a +4 in your hand to stack it.")
    tap(erin, 2)
    assert has_element?(erin, ".toast", "Draw 4, challenge, or stack a +4 first")
  end

  test "a playable drawn card can be played or kept", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> %{game | draw_pile: [c(500, :red, 8) | game.draw_pile]} end)
    erin |> element(".actions button", "Draw") |> render_click()

    assert has_element?(erin, ".sheet h2", "You drew a red 8")
    erin |> element(".sheet button", "Keep it") |> render_click()
    assert has_element?(erin, ".turn", "Bob's turn")
  end

  test "a starting Wild asks the first player for the color", %{erin: erin} do
    use_deck(deck_starting_with(2, :wild))
    start!()

    assert has_element?(erin, ".sheet h2", "Pick the starting color")
    erin |> element(".swatch.blue") |> render_click()
    assert Room.get_state().game.color == :blue
  end

  test "the winner's phone says You won!", %{erin: erin} do
    start!()
    tweak_game(erin, fn game -> put_in(game.hands["erin"], [c(2, :red, 1)]) end)
    tap(erin, 2)

    assert has_element?(erin, "h1.huge", "You won!")
    assert has_element?(erin, ".wait", "Waiting for the table")
  end

  test "someone joining mid-round waits in line" do
    start!()
    {:ok, carol, _html} = live(phone(build_conn(), "carol"), ~p"/")
    carol |> form("#join", %{name: "Carol"}) |> render_submit()

    assert has_element?(carol, "h1", "You're #1 in line.")
    assert has_element?(carol, ".lead", "A game is in progress. You'll play in the next one.")
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party_web/live/uno_phone_test.exs`
Expected: FAIL (no UNO screens yet), e.g. `"the lobby lists the players"` fails on `.wait`.

- [ ] **Step 3: Implement the component**

Create `lib/lan_party_web/live/uno/player_component.ex`:

```elixir
defmodule LanPartyWeb.Uno.PlayerComponent do
  @moduledoc """
  UNO on a phone: lobby, queue, the round, prompts, and the result. Rendered by `PlayerLive` once the
  table picks UNO. Never shows the pile or the current color (uno/docs/README.md "Views").
  Markup follows mockups/phone/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.Uno.Components

  alias LanParty.Room
  alias LanParty.Uno.{Card, View}

  @colors %{"red" => :red, "yellow" => :yellow, "green" => :green, "blue" => :blue}

  @doc "Class for the phone's <main>: brighter when you must act; the winning color at the end."
  def glow(%{phase: :playing, game: game}, token) do
    if game.current == token and not match?({:start_color, _}, game.pending), do: "glow-turn"
  end

  def glow(%{phase: :finished, game: %{color: color}}, _token) when not is_nil(color), do: "glow-#{color}"
  def glow(_room, _token), do: nil

  # Overriding update/2 means LiveView no longer assigns :id for us; the template needs it.
  @impl true
  def update(%{id: id, room: room, token: token}, socket) do
    in_round? = not is_nil(room.game) and Map.has_key?(room.game.hands, token)
    view = if in_round?, do: View.player_view(room.game, token)

    {:ok,
     socket
     |> assign(id: id, room: room, token: token, view: view)
     |> assign(screen: screen(room, room.people[token], in_round?), stage: stage(view, room), hint: hint(view))
     |> assign_new(:sheet, fn -> nil end)
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:dismissed, fn -> nil end)
     |> close_sheet_outside_round()}
  end

  # A picker left open when the round ends must not come back in the next one.
  defp close_sheet_outside_round(%{assigns: %{room: %{phase: :playing}}} = socket), do: socket
  defp close_sheet_outside_round(socket), do: assign(socket, sheet: nil)

  ## Events

  @impl true
  def handle_event("play", %{"id" => id}, socket) do
    with {card_id, ""} <- Integer.parse(id),
         %{hand: hand} = view <- socket.assigns.view,
         %Card{} = card <- Enum.find(hand, &(&1.id == card_id)) do
      cond do
        Card.wild?(card) -> {:noreply, assign(socket, sheet: {:color, card_id}, error: nil)}
        card.value == 7 and view.seven_zero? -> {:noreply, assign(socket, sheet: {:swap, card_id}, error: nil)}
        true -> act(socket, {:play, card_id, %{}})
      end
    else
      _no_such_card -> {:noreply, socket}
    end
  end

  def handle_event("pick_color", %{"color" => color}, socket) do
    case {socket.assigns.sheet, Map.fetch(@colors, color)} do
      {{:color, card_id}, {:ok, color}} -> act(socket, {:play, card_id, %{color: color}})
      _other -> {:noreply, socket}
    end
  end

  def handle_event("pick_player", %{"token" => target}, socket) do
    case socket.assigns.sheet do
      {:swap, card_id} -> act(socket, {:play, card_id, %{swap_with: target}})
      _other -> {:noreply, socket}
    end
  end

  def handle_event("start_color", %{"color" => color}, socket) do
    case Map.fetch(@colors, color) do
      {:ok, color} -> act(socket, {:choose_color, color})
      :error -> {:noreply, socket}
    end
  end

  def handle_event("cancel", _params, socket), do: {:noreply, assign(socket, sheet: nil)}

  def handle_event("dismiss", _params, socket) do
    dismissed = socket.assigns.view && socket.assigns.view.last_challenge
    {:noreply, assign(socket, error: nil, dismissed: dismissed)}
  end

  def handle_event(action, _params, socket) when action in ~w(draw keep accept challenge),
    do: act(socket, String.to_existing_atom(action))

  defp act(socket, action) do
    case Room.act(socket.assigns.token, action) do
      :ok -> {:noreply, assign(socket, error: nil, sheet: nil)}
      {:error, reason} -> {:noreply, assign(socket, error: message(reason, socket.assigns.view), sheet: nil)}
    end
  end

  ## What to show

  defp screen(_room, %{status: :queued}, _in_round?), do: :queue
  defp screen(%{phase: :playing}, _me, true), do: :playing
  defp screen(%{phase: :finished}, _me, _in_round?), do: :finished
  defp screen(_room, _me, _in_round?), do: :lobby

  defp stage(nil, _room), do: nil

  defp stage(view, room) do
    case view.prompt do
      {:penalty, total, _can_challenge?} -> {:penalty, total, view.last_played_by && Room.name(room, view.last_played_by)}
      :choose_start_color -> :start_color
      _other -> if view.my_turn?, do: :my_turn, else: {:turn, Room.name(room, view.current)}
    end
  end

  defp hint(%{prompt: {:penalty, _total, _challenge?}, stack_options: [_ | _] = options}),
    do: "Or tap a #{stack_label(options)} in your hand to stack it."

  defp hint(_view), do: nil

  defp stack_label([:draw2]), do: "+2"
  defp stack_label([:wild_draw4]), do: "+4"
  defp stack_label(_both), do: "+2 or +4"

  # The bottom sheet, if any: a local picker first, then what the game is asking for.
  defp sheet({:color, _card_id}, %{prompt: {:penalty, total, _}, next: next}, room),
    do: {:color, "Pick a color for your +4", "#{Room.name(room, next)} faces +#{total + 4}."}

  defp sheet({:color, _card_id}, _view, _room), do: {:color, "Pick a color", nil}
  defp sheet({:swap, _card_id}, _view, _room), do: :swap
  defp sheet(nil, %{prompt: :choose_start_color}, _room), do: :start_color
  defp sheet(nil, %{prompt: {:drawn, card}}, _room), do: {:drawn, card}
  defp sheet(_sheet, _view, _room), do: nil

  defp message(:not_your_turn, _view), do: "Not your turn"
  defp message(:does_not_match, view), do: "Doesn't match: #{top_label(view)}"
  defp message(:resolve_penalty, view), do: penalty_message(view)
  defp message(:choose_start_color, _view), do: "Pick the starting color first"
  defp message(:play_drawn_or_keep, _view), do: "Play the card you drew, or keep it"
  defp message(_reason, _view), do: "You can't do that right now"

  defp top_label(%{top: top, color: color}) do
    if Card.wild?(top), do: "#{Card.label(top)} (#{color})", else: Card.label(top)
  end

  defp penalty_message(%{prompt: {:penalty, total, can_challenge?}, stack_options: options}) do
    choices =
      ["Draw #{total}"] ++
        if(can_challenge?, do: ["challenge"], else: []) ++
        if(options != [], do: ["stack a #{stack_label(options)}"], else: [])

    or_join(choices) <> " first"
  end

  defp penalty_message(_view), do: "Take the penalty first"

  defp or_join([one]), do: one
  defp or_join([first, second]), do: "#{first} or #{second}"
  defp or_join(choices), do: Enum.join(Enum.drop(choices, -1), ", ") <> ", or " <> List.last(choices)

  # After a challenge, both people involved get a message until they tap OK or someone acts.
  defp challenge_note(%{last_challenge: %{} = result}, room, token, dismissed) when result != dismissed do
    by = Room.name(room, result.by)
    challenger = Room.name(room, result.challenger)

    cond do
      token == result.challenger and result.legal -> "#{by} had no #{result.color} card, so the +4 was fair. You drew 6."
      token == result.challenger -> "#{by} had a #{result.color} card, so #{by} drew 4."
      token == result.by and result.legal -> "#{challenger} challenged your +4 and drew 6."
      token == result.by -> "#{challenger} caught your bluff. You had a #{result.color} card, so you drew 4."
      true -> nil
    end
  end

  defp challenge_note(_view, _room, _token, _dismissed), do: nil

  defp queue_number(room, token), do: Enum.find_index(Room.queued(room), &(&1 == token)) + 1

  defp cards(1), do: "1 card"
  defp cards(n), do: "#{n} cards"

  defp winner_line(%{winner: token}, token), do: "You won!"
  defp winner_line(room, _token), do: "#{Room.name(room, room.winner) || "Someone"} won"

  ## Render

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        current_sheet: sheet(assigns.sheet, assigns.view, assigns.room),
        note: challenge_note(assigns.view, assigns.room, assigns.token, assigns.dismissed)
      )

    ~H"""
    <div id={@id} style="display: contents">
      <div :if={@screen == :lobby} class="message">
        <h1>You're in.</h1>
        <p class="wait">Waiting for the table to start</p>
        <div>
          <p class="people-label">Players</p>
          <ul class="people">
            <li :for={token <- Room.seated(@room)} class={token == @token && "you"}>
              {Room.name(@room, token)}{if token == @token, do: " (you)"}
            </li>
          </ul>
        </div>
      </div>

      <div :if={@screen == :queue} class="message">
        <h1>{"You're ##{queue_number(@room, @token)} in line."}</h1>
        <p :if={@room.phase != :lobby} class="lead">A game is in progress. You'll play in the next one.</p>
        <p :if={@room.phase != :lobby} class="wait">Waiting for this round to end</p>
        <p :if={@room.phase == :lobby} class="lead">The table is full. You'll play in the next one.</p>
        <p :if={@room.phase == :lobby} class="wait">Waiting for a free seat</p>
      </div>

      <div :if={@screen == :finished} class="message centered">
        <.card card={LanParty.Uno.Rules.top_card(@room.game)} />
        <h1 class="huge">{winner_line(@room, @token)}</h1>
        <p :if={@room.winner != @token} class="lead">
          Last card: {Card.label(LanParty.Uno.Rules.top_card(@room.game))}
        </p>
        <p class="wait">Waiting for the table</p>
      </div>

      <%= if @screen == :playing do %>
        <div class="stage">
          <%= case @stage do %>
            <% {:penalty, total, by} -> %>
              <p class="threat"><b>+{total}</b>coming at you</p>
              <p :if={by} class="threat-sub">{by} played it.</p>
            <% :start_color -> %>
              <p class="turn">You go first</p>
            <% :my_turn -> %>
              <p class="your-turn">Your turn</p>
              <p class="stage-hint">Match the top card on the table.</p>
            <% {:turn, name} -> %>
              <p class="turn">{name}'s turn</p>
          <% end %>
        </div>

        <p :if={@hint} class="hint">{@hint}</p>
        <.toast :if={@error} message={@error} phx-click="dismiss" phx-target={@myself} />
        <.toast :if={@note && !@error} message={@note} phx-click="dismiss" phx-target={@myself} />

        <section aria-label="Your hand">
          <div class={["hand", length(@view.hand) == 1 && "one"]}>
            <.card_button
              :for={card <- @view.hand}
              card={card}
              phx-click="play"
              phx-value-id={card.id}
              phx-target={@myself}
            />
          </div>
        </section>

        <div class="actions">
          <%= case @view.prompt do %>
            <% {:penalty, total, can_challenge?} -> %>
              <button class="btn btn-primary" phx-click="accept" phx-target={@myself}>Draw {total}</button>
              <button :if={can_challenge?} class="btn btn-secondary" phx-click="challenge" phx-target={@myself}>
                Challenge
              </button>
            <% _other -> %>
              <button class="btn btn-secondary" phx-click="draw" phx-target={@myself}>Draw</button>
          <% end %>
        </div>

        <%= case @current_sheet do %>
          <% {:color, title, sub} -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">{title}</h2>
              <p :if={sub} class="sub">{sub}</p>
              <div class="swatches">
                <a
                  :for={color <- ~w(red yellow green blue)}
                  class={["swatch", color]}
                  phx-click="pick_color"
                  phx-value-color={color}
                  phx-target={@myself}
                >
                  {String.capitalize(color)}
                </a>
              </div>
              <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
            </section>
          <% :swap -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">Swap hands with…</h2>
              <p class="sub">You played a 7. They get your hand, you get theirs.</p>
              <div class="pick-list">
                <a :for={token <- @view.others} phx-click="pick_player" phx-value-token={token} phx-target={@myself}>
                  {Room.name(@room, token)}<span>{cards(@view.counts[token])}</span>
                </a>
              </div>
              <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
            </section>
          <% :start_color -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">Pick the starting color</h2>
              <p class="sub">The first card is a Wild.</p>
              <div class="swatches">
                <a
                  :for={color <- ~w(red yellow green blue)}
                  class={["swatch", color]}
                  phx-click="start_color"
                  phx-value-color={color}
                  phx-target={@myself}
                >
                  {String.capitalize(color)}
                </a>
              </div>
            </section>
          <% {:drawn, card} -> %>
            <div class="scrim"></div>
            <section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
              <h2 id="sheet-title">You drew a {Card.label(card)}</h2>
              <div class="drawn"><.card card={card} /></div>
              <div class="actions">
                <button class="btn btn-primary" phx-click="play" phx-value-id={card.id} phx-target={@myself}>
                  Play it
                </button>
                <button class="btn btn-secondary" phx-click="keep" phx-target={@myself}>Keep it</button>
              </div>
            </section>
          <% nil -> %>
        <% end %>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 4: Render it from `PlayerLive`**

In `lib/lan_party_web/live/player_live.ex`:

Replace the line `<%!-- GAME SCREENS: Task 11 renders the UNO component here. --%>` with:

```heex
      <.live_component
        :if={@me && @room.game_id == :uno}
        module={LanPartyWeb.Uno.PlayerComponent}
        id="uno-phone"
        room={@room}
        token={@token}
      />
```

In `assign_room/2`, replace `glow: nil` with:

```elixir
      glow: if(me && room.game_id == :uno, do: LanPartyWeb.Uno.PlayerComponent.glow(room, socket.assigns.token))
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `mix test test/lan_party_web`
Expected: all pass.

- [ ] **Step 6: Compare against the mockups**

Run `mix phx.server`. On the table (`/table`) pick UNO; join from two browser windows in phone
emulation (one normal, one private, so they get different tokens); start; play a few turns. Compare
each phone screen you reach with the mockup file of the same name listed at the top of this task. If
a mockup changed since this plan was written, align markup and copy with it.

---

### Task 12: UNO on the table

**Files:**
- Create: `lib/lan_party_web/live/uno/table_component.ex`
- Modify: `lib/lan_party_web/live/table_live.ex`
- Test: `test/lan_party_web/live/uno_table_test.exs`

**Interfaces:**
- Consumes: `View.table_view/1`, `Room` table actions and readers, `Uno.Components.card/1`.
- Produces: `LanPartyWeb.Uno.TableComponent` (LiveComponent, id `"uno-table"`, assign `room`) and
  `TableComponent.main_class/1 :: String.t()` for the table's `<main>`.

Screens and copy come from `mockups/table/uno-lobby.html`, `uno-lobby-waiting.html`,
`uno-playing.html`, `uno-draw-for-*.html`, `uno-reset.html`, `uno-finished.html`.

- [ ] **Step 1: Write the failing tests**

Create `test/lan_party_web/live/uno_table_test.exs`:

```elixir
defmodule LanPartyWeb.UnoTableTest do
  use LanPartyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LanParty.UnoHelpers

  alias LanParty.Room

  # Erin and Bob; with the fixed deck Erin goes first and red 5 starts the pile.
  setup %{conn: conn} do
    restart_room()
    :sys.replace_state(Room, &%{&1 | game_opts: [deck: deck_starting_with(2, 5), first_player: "erin"]})
    :ok = Room.join("erin", "Erin", page())
    :ok = Room.pick_game(:uno)
    {:ok, table, _html} = live(conn, ~p"/table")
    %{table: table}
  end

  defp page, do: spawn(fn -> Process.sleep(:infinity) end)

  defp start_round(table) do
    :ok = Room.join("bob", "Bob", page())
    table |> element("button", "Start game") |> render_click()
  end

  test "the lobby waits for a second player", %{table: table} do
    assert has_element?(table, ".game-name", "UNO")
    assert has_element?(table, ".people li", "Erin")
    assert has_element?(table, ".lobby-note .wait", "Waiting for players to join")
    assert has_element?(table, "button[disabled]", "Start game")
    assert has_element?(table, ".start-row p", "Start needs at least 2 players.")
  end

  test "with two players the table can start", %{table: table} do
    :ok = Room.join("bob", "Bob", page())

    assert has_element?(table, ".lobby-note", "2 of 8 seats taken.")
    refute has_element?(table, "button[disabled]", "Start game")
  end

  test "house rules switch on and off", %{table: table} do
    table |> element("#rule-jump_in") |> render_click()

    assert Room.get_state().settings.jump_in
    assert has_element?(table, "#rule-jump_in[checked]")
  end

  test "Change game goes back to Select the game", %{table: table} do
    table |> element("button", "Change game") |> render_click()

    assert Room.get_state().phase == :picking
    assert has_element?(table, "h1", "Select the game")
  end

  test "during a round the table shows seats, the pile and whose turn it is", %{table: table} do
    start_round(table)

    assert has_element?(table, ".seat.current .name", "Erin")
    assert has_element?(table, ".seat .count", "7")
    assert has_element?(table, ".table-info .turn", "Erin's turn")
    assert has_element?(table, ".facts", "Color: red")
    assert has_element?(table, ".top-card .card.red")
    assert has_element?(table, "main.glow-red")
    refute has_element?(table, "button", "Change game")
  end

  test "draw for player: tap a seat, pick the amount, Draw", %{table: table} do
    start_round(table)
    table |> element(".seat", "Bob") |> render_click()

    assert has_element?(table, ".modal h2", "Make Bob draw")
    assert has_element?(table, ".stepper output", "2")
    table |> element(".stepper button[aria-label='One more']") |> render_click()
    assert has_element?(table, ".stepper output", "3")

    table |> element(".modal button", "Draw") |> render_click()
    assert length(Room.get_state().game.hands["bob"]) == 10
    refute has_element?(table, ".modal")
  end

  test "Reset asks before ending the round", %{table: table} do
    start_round(table)

    table |> element("button", "Reset") |> render_click()
    assert has_element?(table, ".modal h2", "End this round?")
    table |> element(".modal button", "Cancel") |> render_click()
    assert Room.get_state().phase == :playing

    table |> element("button", "Reset") |> render_click()
    table |> element(".modal button", "End round") |> render_click()
    assert Room.get_state().phase == :lobby
  end

  test "the winner screen, then Play again", %{table: table} do
    start_round(table)
    :sys.replace_state(Room, fn state -> put_in(state.game.hands["erin"], [c(2, :red, 1)]) end)
    :ok = Room.act("erin", {:play, 2, %{}})

    assert has_element?(table, ".winner h1", "Erin won")
    assert has_element?(table, ".leftovers", "Bob")

    table |> element("button", "Play again") |> render_click()
    assert Room.get_state().phase == :lobby
  end
end
```

- [ ] **Step 2: Run them to see them fail**

Run: `mix test test/lan_party_web/live/uno_table_test.exs`
Expected: FAIL (no UNO table screens yet), e.g. on `.game-name`.

- [ ] **Step 3: Implement the component**

Create `lib/lan_party_web/live/uno/table_component.ex`:

```elixir
defmodule LanPartyWeb.Uno.TableComponent do
  @moduledoc """
  UNO on the table: the lobby (house rules, Start, Change game), the round (seats, pile, draw for
  player, Reset), and the result. Rendered by `TableLive` once UNO is picked.
  Markup follows mockups/table/.
  """
  use LanPartyWeb, :live_component

  import LanPartyWeb.Uno.Components

  alias LanParty.Room
  alias LanParty.Uno.View

  @rules [
    {:stack_plus2, "Stacking +2s", "Answer a +2 with a +2 and pass the total on."},
    {:stack_plus4, "Stacking +4s", "Answer a +4 with a +4 and pass the total on."},
    {:seven_zero, "7-0", "A 7 swaps hands with a player you pick. A 0 passes every hand along."},
    {:jump_in, "Jump-in", "Anyone can play an identical card out of turn. Play carries on from them."}
  ]

  @doc "Class for the table's <main>: the current color glows during and after a round."
  def main_class(%{phase: phase, game: %{color: color}})
      when phase in [:playing, :finished] and not is_nil(color),
      do: "tv glow-#{color}"

  def main_class(_room), do: "tv"

  # Overriding update/2 means LiveView no longer assigns :id for us; the template needs it.
  @impl true
  def update(%{id: id, room: room}, socket) do
    view = if room.game, do: View.table_view(room.game)
    {top_row, bottom_row} = rows(view)

    {:ok,
     socket
     |> assign(id: id, room: room, view: view, rules: @rules, top_row: top_row, bottom_row: bottom_row)
     |> assign(seated: Room.seated(room), queued: Room.queued(room), leftovers: leftovers(view, room))
     |> assign_new(:draw_for, fn -> nil end)
     |> assign_new(:amount, fn -> 2 end)
     |> assign_new(:confirm_reset, fn -> false end)
     |> assign_new(:error, fn -> nil end)
     |> close_panels_outside_round()}
  end

  ## Events

  @impl true
  def handle_event("change_game", _params, socket), do: reply(socket, Room.change_game())
  def handle_event("start", _params, socket), do: reply(socket, Room.start_game())

  def handle_event("toggle", %{"rule" => rule}, socket) do
    case Enum.find(@rules, fn {key, _title, _help} -> Atom.to_string(key) == rule end) do
      {key, _title, _help} -> reply(socket, Room.update_settings(%{key => !socket.assigns.room.settings[key]}))
      nil -> {:noreply, socket}
    end
  end

  def handle_event("open_draw_for", %{"token" => token}, socket) do
    if socket.assigns.room.phase == :playing and Map.has_key?(socket.assigns.room.game.hands, token),
      do: {:noreply, assign(socket, draw_for: token, amount: 2)},
      else: {:noreply, socket}
  end

  def handle_event("amount", %{"delta" => delta}, socket) do
    change = if delta == "1", do: 1, else: -1
    {:noreply, assign(socket, amount: (socket.assigns.amount + change) |> max(1) |> min(10))}
  end

  def handle_event("confirm_draw_for", _params, socket) do
    result = Room.draw_for(socket.assigns.draw_for, socket.assigns.amount)
    reply(assign(socket, draw_for: nil), result)
  end

  def handle_event("ask_reset", _params, socket), do: {:noreply, assign(socket, confirm_reset: true)}
  def handle_event("cancel", _params, socket), do: {:noreply, assign(socket, draw_for: nil, confirm_reset: false)}

  def handle_event("back_to_lobby", _params, socket),
    do: reply(assign(socket, confirm_reset: false), Room.back_to_lobby())

  defp reply(socket, :ok), do: {:noreply, assign(socket, error: nil)}
  defp reply(socket, {:error, :not_enough_players}), do: {:noreply, assign(socket, error: "Start needs at least 2 players.")}
  defp reply(socket, {:error, _reason}), do: {:noreply, assign(socket, error: "That didn't work. Try again.")}

  ## What to show

  defp close_panels_outside_round(%{assigns: %{room: %{phase: :playing}}} = socket), do: socket
  defp close_panels_outside_round(socket), do: assign(socket, draw_for: nil, confirm_reset: false)

  # Seats around the table: the first half along the top, the rest along the bottom, right to left.
  defp rows(nil), do: {[], []}

  defp rows(%{counts: counts}) do
    {top, bottom} = Enum.split(counts, div(length(counts) + 1, 2))
    {top, Enum.reverse(bottom)}
  end

  defp leftovers(nil, _room), do: []
  defp leftovers(view, room), do: Enum.reject(view.counts, fn {token, _count} -> token == room.winner end)

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
  attr :current, :string, required: true
  attr :target, :any, required: true

  defp seat(assigns) do
    ~H"""
    <a
      class={["seat", @token == @current && "current", away?(@room, @token) && "away"]}
      phx-click="open_draw_for"
      phx-value-token={@token}
      phx-target={@target}
    >
      <span class="name">{Room.name(@room, @token)}</span>
      <span class="count">{@count}<small>{if @count == 1, do: "card", else: "cards"}</small></span>
      <span :if={away?(@room, @token)} class="tag">Away</span>
    </a>
    """
  end

  ## Render

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} style="display: contents">
      <%= case @room.phase do %>
        <% :lobby -> %>
          <header class="tv-head">
            <span class="game-name">UNO</span>
            <button class="btn btn-secondary" phx-click="change_game" phx-target={@myself}>Change game</button>
          </header>
          <div class="lobby">
            <section>
              <h2>Players</h2>
              <ul class="people">
                <li :for={token <- @seated}>{Room.name(@room, token)}</li>
              </ul>
              <p :if={length(@seated) >= 2} class="lobby-note">{length(@seated)} of 8 seats taken.</p>
              <p :if={length(@seated) < 2} class="lobby-note"><span class="wait">Waiting for players to join</span></p>
              <p :if={@queued != []} class="lobby-note">Waiting for a seat: {Enum.join(names(@room, @queued), ", ")}</p>
            </section>
            <section>
              <h2>House rules</h2>
              <div class="rules">
                <label :for={{key, title, help} <- @rules} class="rule" for={"rule-#{key}"}>
                  <span><b>{title}</b><small>{help}</small></span>
                  <input
                    class="switch"
                    type="checkbox"
                    id={"rule-#{key}"}
                    checked={@room.settings[key]}
                    phx-click="toggle"
                    phx-value-rule={key}
                    phx-target={@myself}
                  />
                </label>
              </div>
            </section>
          </div>
          <div class="start-row">
            <button
              class="btn btn-primary btn-big"
              phx-click="start"
              phx-target={@myself}
              disabled={length(@seated) < 2}
            >
              Start game
            </button>
            <p :if={length(@seated) < 2}>Start needs at least 2 players.</p>
            <p :if={@error} role="alert">{@error}</p>
          </div>
        <% :playing -> %>
          <header class="tv-head">
            <span class="game-name">UNO</span>
            <button class="btn btn-secondary" phx-click="ask_reset" phx-target={@myself}>Reset</button>
          </header>
          <div class="ring">
            <div class="seats" style={"grid-template-columns: repeat(#{max(length(@top_row), 1)}, 1fr)"}>
              <.seat
                :for={{token, count} <- @top_row}
                token={token}
                count={count}
                room={@room}
                current={@view.current}
                target={@myself}
              />
            </div>
            <div class="table-mid">
              <div class="draw-pile">
                <span class="card black stack" role="img" aria-label="Draw pile"><span class="face" aria-hidden="true"><span class="oval back-oval"></span><span class="logo">UNO</span></span></span>
                <span>{@view.draw_pile_size} cards</span>
              </div>
              <div class="top-card"><.card card={@view.top} /></div>
              <div class="table-info">
                <p class="turn">{Room.name(@room, @view.current)}'s turn</p>
                <p :if={@view.pending_total > 0} class="pending">
                  <b>+{@view.pending_total}</b> for {Room.name(@room, @view.current)}
                </p>
                <p class="facts">
                  <span>Color: {@view.color || "not picked yet"}</span>
                  <span>
                    <svg aria-hidden="true" style={@view.direction == -1 && "transform: scaleX(-1)"}>
                      <use href="#clockwise" />
                    </svg>{if @view.direction == 1, do: "Clockwise", else: "Counterclockwise"}
                  </span>
                </p>
              </div>
            </div>
            <div class="seats" style={"grid-template-columns: repeat(#{max(length(@bottom_row), 1)}, 1fr)"}>
              <.seat
                :for={{token, count} <- @bottom_row}
                token={token}
                count={count}
                room={@room}
                current={@view.current}
                target={@myself}
              />
            </div>
          </div>
          <footer class="tv-foot">
            <span :if={@queued != []}>Next game: <strong>{Enum.join(names(@room, @queued), ", ")}</strong></span>
            <span :if={@queued == []}></span>
            <span>Tap a player to make them draw.</span>
          </footer>

          <div :if={@draw_for} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">Make {Room.name(@room, @draw_for)} draw</h2>
              <div class="stepper">
                <button type="button" aria-label="One fewer" phx-click="amount" phx-value-delta="-1" phx-target={@myself}>−</button>
                <output aria-live="polite">{@amount}</output>
                <button type="button" aria-label="One more" phx-click="amount" phx-value-delta="1" phx-target={@myself}>+</button>
              </div>
              <p>2 cards is the penalty for not saying UNO.</p>
              <div class="buttons">
                <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn btn-primary" phx-click="confirm_draw_for" phx-target={@myself}>Draw</button>
              </div>
            </div>
          </div>

          <div :if={@confirm_reset} class="modal-scrim">
            <div class="modal" role="dialog" aria-modal="true" aria-labelledby="dlg">
              <h2 id="dlg">End this round?</h2>
              <p>Nobody wins, and everyone goes back to the lobby.</p>
              <div class="buttons">
                <button class="btn btn-secondary" phx-click="cancel" phx-target={@myself}>Cancel</button>
                <button class="btn btn-primary" phx-click="back_to_lobby" phx-target={@myself}>End round</button>
              </div>
            </div>
          </div>
        <% :finished -> %>
          <header class="tv-head"><span class="game-name">UNO</span></header>
          <section class="winner">
            <.card card={@view.top} />
            <h1>{Room.name(@room, @room.winner) || "Someone"} won</h1>
            <p class="leftovers">
              <span>Cards left</span>
              <span :for={{token, count} <- @leftovers}>{Room.name(@room, token)} <b>{count}</b></span>
            </p>
            <div class="buttons">
              <button class="btn btn-primary btn-big" phx-click="back_to_lobby" phx-target={@myself}>Play again</button>
            </div>
            <p :if={@queued != []} class="lobby-note">{join_note(names(@room, @queued))}</p>
          </section>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 4: Render it from `TableLive`**

In `lib/lan_party_web/live/table_live.ex`:

Replace the line `<%!-- GAME SCREENS: Task 12 renders the UNO component here. --%>` with:

```heex
      <.live_component
        :if={@room.game_id == :uno}
        module={LanPartyWeb.Uno.TableComponent}
        id="uno-table"
        room={@room}
      />
```

In `assign_room/2`, replace the `main_class:` line with:

```elixir
      main_class:
        if(is_nil(room.game_id), do: "tv shelf-room", else: LanPartyWeb.Uno.TableComponent.main_class(room)),
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `mix test`
Expected: the whole suite passes, no compiler warnings.

- [ ] **Step 6: Compare against the mockups**

Run `mix phx.server`, open `/table` in a wide browser window and play a round with two phone windows
(normal + private). Compare the lobby, the round, the draw-for panel, the Reset question and the
winner screen with the mockup files listed at the top of this task; align markup and copy if the
mockups changed.

---

### Task 13: Host instructions and the party test

**Files:**
- Replace: `README.md` (the one `mix phx.new` generated at the repo root)
- Modify: `CLAUDE.md` ("Status" and "Where things live")

**Interfaces:**
- Consumes: everything above.
- Produces: a README the host can follow, and a manual check of every success criterion.

- [ ] **Step 1: Write the host README**

Replace `README.md` with:

```markdown
# LAN Party

Party games on your own computer. Guests play from their phone browsers on the same Wi-Fi; a TV or
iPad is the table. Nothing to install for guests.

## First time on this computer

1. Install Erlang/OTP and Elixir: https://elixir-lang.org/install.html#windows
2. In this folder, run `mix setup`.

## Every party

1. Connect this computer to the party Wi-Fi.
2. Run `mix phx.server`.
3. The first time, Windows asks whether to let `erl.exe` through the firewall: allow **Private
   networks**.
4. The log prints two addresses:
   - `Players: http://<ip>:4000/` — tell your guests.
   - `Table:   http://<ip>:4000/table` — open it on the TV or iPad, then pick a game.

   If several lines are printed, use the one labelled with your Wi-Fi adapter.
5. Stop with Ctrl+C twice.

## For developers

- `mix test` runs everything.
- Read `CLAUDE.md` first; UNO's rules and design are in `uno/docs/`; the screens follow `mockups/`.
```

- [ ] **Step 2: Update `CLAUDE.md`**

In "Status", set the stage line to:

```markdown
- **Stage:** First build implemented (platform + UNO). See "Where things live" for the code.
```

In "Where things live", change the `lib/`, `test/` row's text from "(not created yet) A standard
Phoenix project…" to "The Phoenix project (platform + UNO); layout in `uno/docs/design.md` §3".

- [ ] **Step 3: Run the whole suite**

Run: `mix test`
Expected: all tests pass, no compiler warnings.

- [ ] **Step 4: The party test (manual, on real devices)**

With the computer and at least two phones and one tablet/TV on the same Wi-Fi:

1. `mix phx.server`. Expected: the banner shows `Players:` and `Table:` URLs.
2. Open the Table URL on the tablet/TV. Expected: "Select the game" with UNO and 7 "Not built yet".
3. Open the Players URL on each phone and join. Expected: "Waiting for the table to pick a game"; the
   table lists the names.
4. Tap **Play UNO** on the table. Expected: every phone switches to the UNO lobby on its own.
5. Switch a house rule on, **Start game**, and play a full round to a winner. Expected: illegal taps
   show a short message; the phone never shows the pile; the table shows the pile, color, turn and
   counts.
6. Lock one phone for ~10 s, unlock it. Expected: same seat, same hand.
7. Lock one phone for ~40 s. Expected: the table marks it *Away*, then it disappears from the round;
   on unlock the phone shows "You were away too long…" and can join again (queued if a round runs).
8. Use **draw for player**, **Reset** (check the question appears), **Play again**, and
   **Change game**. Expected: each matches the spec and the mockups.

Write down anything that didn't match and fix it before calling the build done.
