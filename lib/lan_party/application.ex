defmodule LanParty.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: LanParty.PubSub},
      LanParty.Room,
      # Start to serve requests, typically the last entry
      LanPartyWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LanParty.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      if Application.get_env(:lan_party, :print_urls, true) do
        LanParty.LanAddress.print_banner(LanPartyWeb.Endpoint.config(:http)[:port])
      end

      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LanPartyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
