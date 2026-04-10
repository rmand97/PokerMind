defmodule PokerMind.Engine.Match.Game do
  alias PokerMind.Engine
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.TableState
  use GenServer

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: Engine.Registry.via(name))
  end

  def get_state(game_id) do
    GenServer.call(Engine.Registry.via(game_id), :get_state)
  end

  def apply_action(game_id, action, player) do
    GenServer.call(Engine.Registry.via(game_id), {:apply_action, action, player})
  end

  @impl true
  def init(init_args) do
    coordinator_id = Keyword.fetch!(init_args, :coordinator_id)
    name = Keyword.fetch!(init_args, :name)
    players = Keyword.fetch!(init_args, :players)

    Process.set_label(name)

    game = TableState.init(TableState.new(name), players)

    {:ok, %{coordinator_id: coordinator_id, id: name, game: game},
     {:continue, :notify_coordinator}}
  end

  def id(suite_id, game_num) do
    "#{suite_id}-#{game_num}"
  end

  @impl true
  def handle_continue(:notify_coordinator, state) do
    :ok =
      Coordinator.register_game_ready(
        state.coordinator_id,
        state.id,
        state.game.current_player_id
      )

    {:noreply, state}
  end

  @impl true
  def handle_call({:apply_action, _action, _player}, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.game, state}
  end
end
