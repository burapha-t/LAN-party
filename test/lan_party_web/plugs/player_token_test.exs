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
