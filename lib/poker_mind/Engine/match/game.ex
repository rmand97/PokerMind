defmodule PokerMind.Engine.Match.Game do
  alias PokerMind.Engine
  use GenServer

  # Game code

  defstruct [:players, :id]

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: Engine.Registry.via(name))
  end

  @impl true
  def init(init_args) do
    coordinator_id = Keyword.fetch!(init_args, :coordinator_id)
    name = Keyword.fetch!(init_args, :name)
    Process.set_label(name)

    {:ok, %{coordinator_id: coordinator_id}, {:continue, :notify_coordinator}}
  end

  @impl true
  def handle_continue(:notify_coordinator, state) do
    starting_player = "rolf"
    GenServer.cast(Engine.Registry.via(state.coordinator_id), {:ready, starting_player})
    {:noreply, state}
  end

  def add_player(%__MODULE__{} = gamestate, new_player) do
    current_players = gamestate.players

    updated_players = [new_player | current_players]

    Map.put(gamestate, :players, updated_players)
  end
end
