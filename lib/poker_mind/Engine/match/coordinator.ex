defmodule PokerMind.Engine.Match.Coordinator do
  alias PokerMind.Engine
  alias PokerMind.Engine.Match.Game
  use GenServer

  @init_state %{
    all_games_ready: false,
    games: %{},
    num_games: nil
  }

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: Engine.Registry.via(name))
  end

  @impl true
  def init(init_args) do
    name = Keyword.fetch!(init_args, :name)
    num_games = Keyword.fetch!(init_args, :num_games)
    Process.set_label(name)

    state = Map.put(@init_state, :num_games, num_games)

    {:ok, state}
  end

  def get_state(coordinator_id) do
    GenServer.call(Engine.Registry.via(coordinator_id), :get_state)
  end

  def id(parent_id) do
    "#{parent_id}-coordinator"
  end

  def register_game_ready(coordinator_id, game_id, starting_player) do
    GenServer.cast(Engine.Registry.via(coordinator_id), {:ready, game_id, starting_player})
  end

  def next_games(coordinator_id, player, amount \\ 10) do
    GenServer.call(Engine.Registry.via(coordinator_id), {:next_games, player, amount})
  end

  @impl true
  def handle_cast({:ready, game_id, player}, %{all_games_ready: false} = state) do
    updated_state =
      state
      |> put_in([:games, game_id], %{ready: true, next_player: player})
      |> then(fn s -> Map.put(s, :all_games_ready, all_games_ready?(s)) end)

    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # separator for catching all calls for when `all_games_ready` is false
  @impl true
  def handle_call(_, _from, %{all_games_ready: false} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  @impl true
  def handle_call({:next_games, player, amount}, _from, state) do
    response =
      Enum.reduce_while(state.games, {[], 0}, fn {game_id, game_state}, {games, count} = acc ->
        cond do
          # we found amount specified
          count >= amount ->
            {:halt, acc}

          game_state.ready and game_state.next_player == player ->
            updated_games = [game_id | games]
            updated_count = count + 1
            {:cont, {updated_games, updated_count}}

          true ->
            {:cont, acc}
        end
      end)
      |> Kernel.then(fn {game_ids, _count} ->
        Enum.map(game_ids, fn game_id ->
          Game.get_state(game_id)
        end)
      end)

    {:reply, response, state}
  end

  defp all_games_ready?(state) do
    Enum.count(state.games) == state.num_games and
      Enum.all?(state.games, fn {_id, game_state} -> game_state.ready end)
  end
end
