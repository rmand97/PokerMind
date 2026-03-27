defmodule PokerMind.Engine.Match.Supervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_match_suite() do
    id = to_string(:rand.uniform(1000))

    DynamicSupervisor.start_child(__MODULE__, {PokerMind.Engine.Match.Suite, %{id: id}})
    |> case do
      {:ok, pid} -> {:ok, pid, id}
      error -> error
    end
  end
end
