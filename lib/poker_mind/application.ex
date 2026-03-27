defmodule PokerMind.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Boundary, top_level?: true, deps: [PokerMind, PokerMindWeb]
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PokerMindWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:poker_mind, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PokerMind.PubSub},
      # Start a worker by calling: PokerMind.Worker.start_link(arg)
      # {PokerMind.Worker, arg},
      # Start to serve requests, typically the last entry
      PokerMindWeb.Endpoint,
      PokerMind.Engine.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PokerMind.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PokerMindWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
