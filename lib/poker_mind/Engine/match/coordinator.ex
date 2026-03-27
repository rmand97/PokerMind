defmodule PokerMind.Engine.Match.Coordinator do
  alias PokerMind.Engine
  use GenServer

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: Engine.Registry.via(name))
  end

  @impl true
  def init(init_args) do
    name = Keyword.fetch!(init_args, :name)
    Process.set_label(name)

    {:ok, %{}}
  end
end
