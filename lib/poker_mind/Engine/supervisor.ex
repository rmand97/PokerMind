defmodule PokerMind.Engine.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: PokerMind.Engine.Registry},
      PokerMind.Engine.Match.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
