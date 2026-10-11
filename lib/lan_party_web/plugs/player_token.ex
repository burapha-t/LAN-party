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
