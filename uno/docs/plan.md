# UNO First Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Phoenix LiveView server on the host's computer where 2–8 phones join once at `/`, the table
at `/table` picks UNO, and everyone plays a full, rule-enforced round with a TV or iPad as the table.

**Architecture:** Pure UNO rules (`LanParty.Uno.Rules`, no processes) wrapped by one GenServer
(`LanParty.Room`) that owns the night: names, the picked game, seats, queue, settings, disconnects and
kicks. Two LiveViews (`PlayerLive` at `/`, `TableLive` at `/table`) call the Room and re-render from
PubSub broadcasts; once UNO is picked they render UNO LiveComponents for the UNO screens.

**Tech Stack:** Elixir ≥ 1.15, Erlang/OTP ≥ 26, Phoenix 1.8 (whatever `phx_new` installs), Phoenix
LiveView ≥ 1.0, Tailwind (generated). No database, no custom JavaScript.

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
