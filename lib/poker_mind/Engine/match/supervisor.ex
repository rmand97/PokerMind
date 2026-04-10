defmodule PokerMind.Engine.Match.Supervisor do
  use DynamicSupervisor
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
    [{pid, _value}] = Registry.lookup(PokerMind.Engine.Registry, suite_id)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  # Callbacks

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
