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
