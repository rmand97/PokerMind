defmodule PokerMindWeb.Router do
  use PokerMindWeb, :router
  import PokerMindWeb.ApiAuth, only: [fetch_token_and_verify: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PokerMindWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_token_and_verify
  end

  scope "/api", PokerMindWeb do
    pipe_through :api

    get "/next_games", GameController, :next_games
    post "/action", GameController, :perform_action
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:poker_mind, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PokerMindWeb.Telemetry
    end
  end
end
