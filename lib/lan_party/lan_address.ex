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
        names = adapter_names()

        for {name, opts} <- interfaces,
            {:addr, ip} <- opts,
            tuple_size(ip) == 4,
            private_ipv4?(ip),
            do: {friendly_name(List.to_string(name), names), ip}

      {:error, _} ->
        []
    end
  end

  @doc """
  On Windows, `:inet.getifaddrs/0` names adapters `\\DEVICE\\TCPIP_{GUID}`. Returns the adapter's
  name (e.g. "Ethernet") when its GUID is in `names`, otherwise the name unchanged.
  """
  def friendly_name(name, names) do
    case Regex.run(~r/\{[0-9A-Fa-f-]+\}/, name) do
      [guid] -> Map.get(names, String.upcase(guid), name)
      nil -> name
    end
  end

  @doc "Parses lines of `{GUID}|Name` (from `Get-NetAdapter`) into a map keyed by the upper-case GUID."
  def parse_adapters(output) do
    for line <- String.split(output, ["\r\n", "\n"], trim: true),
        [guid, name] <- [String.split(line, "|", parts: 2)],
        into: %{},
        do: {String.upcase(String.trim(guid)), String.trim(name)}
  end

  # Windows only: GUID => adapter name. Empty if PowerShell is missing or fails.
  defp adapter_names do
    with {:win32, _} <- :os.type(),
         {output, 0} <-
           System.cmd("powershell", [
             "-NoProfile",
             "-NonInteractive",
             "-Command",
             "[Console]::OutputEncoding = [Text.Encoding]::UTF8; " <>
               "Get-NetAdapter | ForEach-Object { $_.InterfaceGuid + '|' + $_.Name }"
           ]) do
      parse_adapters(output)
    else
      _ -> %{}
    end
  rescue
    _ -> %{}
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
