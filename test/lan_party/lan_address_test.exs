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
