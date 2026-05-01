defmodule PokerMind.Engine.Match.Game do
  alias PokerMind.Engine
  alias PokerMind.Engine.Actions
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.TableState

  use GenServer

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: Engine.Registry.via(name, :game))
  end

  def get_state(game_id) do
    ensure_exists(game_id, fn ->
      GenServer.call(Engine.Registry.via(game_id, :game), :get_state)
    end)
  end

  def apply_action(game_id, %{action: action_type, player_id: player_id} = action)
      when is_atom(action_type) and is_binary(player_id) do
    ensure_exists(game_id, fn ->
      GenServer.call(Engine.Registry.via(game_id, :game), {:apply_action, action})
    end)
  end

  def id(suite_id, game_num) do
    "#{suite_id}-#{game_num}"
  end

  defp ensure_exists(game_id, fun)
       when is_binary(game_id) and is_function(fun) do
    case Registry.lookup(PokerMind.Engine.Registry, game_id) do
      [{pid, :game}] when is_pid(pid) -> fun.()
      _ -> {:error, :game_not_found}
    end
  end

  # Callbacks

  @impl true
  def init(init_args) do
    coordinator_id = Keyword.fetch!(init_args, :coordinator_id)
    name = Keyword.fetch!(init_args, :name)
    players = Keyword.fetch!(init_args, :players)

    Process.set_label(name)

    game = TableState.init(TableState.new(name), players)

    {:ok, %{coordinator_id: coordinator_id, id: name, game: game, finished?: false},
     {:continue, :notify_coordinator}}
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
  def handle_call({:apply_action, %{action: _, player_id: _}}, _from, %{finished?: true} = state) do
    {:reply, {:error, :game_finished}, state}
  end

  @impl true
  def handle_call(
        {:apply_action, %{action: _, player_id: _} = action},
        _from,
        %{finished?: false} = state
      ) do
    case Actions.apply_action(state.game, action) do
      %TableState{} = new_game_state ->
        finished? = new_game_state.phase == :game_finished

        if finished? do
          Coordinator.register_game_finished(
            state.coordinator_id,
            state.id,
            new_game_state.winner
          )
        end

        {:reply, {:ok, new_game_state}, %{state | game: new_game_state, finished?: finished?}}

      {:error, _msg} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
