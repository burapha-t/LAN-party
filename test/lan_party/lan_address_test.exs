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

  test "parses Windows adapter names keyed by GUID" do
    output = "{FC01FCD5-2B9D-2FD8-78D8-CB78B313E2B2}|NordLynx\r\n{2fe31bf7-b21b-4651-9a26-26f86691a1e4}|Ethernet\r\n\r\n"

    assert LanAddress.parse_adapters(output) == %{
             "{FC01FCD5-2B9D-2FD8-78D8-CB78B313E2B2}" => "NordLynx",
             "{2FE31BF7-B21B-4651-9A26-26F86691A1E4}" => "Ethernet"
           }
  end

  test "Windows device names show as adapter names" do
    names = %{"{2FE31BF7-B21B-4651-9A26-26F86691A1E4}" => "Ethernet"}

    assert LanAddress.friendly_name(~S"\DEVICE\TCPIP_{2FE31BF7-B21B-4651-9A26-26F86691A1E4}", names) ==
             "Ethernet"

    # Unknown GUIDs and non-Windows names stay as they are.
    assert LanAddress.friendly_name(~S"\DEVICE\TCPIP_{00000000-0000-0000-0000-000000000000}", names) ==
             ~S"\DEVICE\TCPIP_{00000000-0000-0000-0000-000000000000}"

    assert LanAddress.friendly_name("en0", names) == "en0"
  end
end
