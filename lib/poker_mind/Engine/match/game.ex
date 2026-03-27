defmodule PokerMind.Engine.Match.Game do
  alias PokerMind.Engine
  use GenServer

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: Engine.Registry.via(name))
  end

  @impl true
  def init(_init_args) do
    {:ok, %{}}
  end

  defstruct [:players, :id]

  def add_player(%__MODULE__{} = gamestate, new_player) do
    current_players = gamestate.players

    updated_players = [new_player | current_players]

    Map.put(gamestate, :players, updated_players)
  end
end
