defmodule LanPartyWeb.Router do
  use LanPartyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LanPartyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug LanPartyWeb.Plugs.PlayerToken
  end

  scope "/", LanPartyWeb do
    pipe_through :browser

    live "/", PlayerLive
    live "/table", TableLive
  end
end
