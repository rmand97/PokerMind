defmodule PokerMind.Engine.Match.Supervisor do
  use DynamicSupervisor
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Suite

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_match_suite(suite_id, players, num_games \\ 10) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Suite, id: suite_id, players: players, num_games: num_games}
    )
    |> case do
      {:ok, pid} -> {:ok, pid, suite_id}
      error -> error
    end
  end

  def close_match_suite(suite_id) do
    case Registry.lookup(PokerMind.Engine.Registry, suite_id) do
      [] ->
        {:error, :suite_not_found}

      [{pid, _value}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  def all_match_suites() do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.flat_map(fn
      {_, pid, _, _} when is_pid(pid) ->
        Registry.keys(PokerMind.Engine.Registry, pid)

      _ ->
        []
    end)
    |> Map.new(fn suite_id ->
      %{players: players} = Coordinator.get_state(Coordinator.id(suite_id))
      {suite_id, players}
    end)
  end

  # Callbacks

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
