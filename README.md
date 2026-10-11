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
