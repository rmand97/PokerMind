defmodule PokerMindWeb.MatchSupport do
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Supervisor

  @ready_poll_interval_ms 20

  def start_match_suite!(suite_id, players, num_games \\ 10) do
    {:ok, pid, ^suite_id} = Supervisor.start_match_suite(suite_id, players, num_games)
    wait_until_coordinator_ready!(suite_id)
    {:ok, pid, suite_id}
  end

  def wait_until_coordinator_ready!(suite_id, retries_left \\ 5) do
    coordinator_id = Coordinator.id(suite_id)
    wait_ready(coordinator_id, retries_left)
  end

  defp wait_ready(coordinator_id, retries_left) do
    if retries_left == 0 do
      raise "Coordinator #{coordinator_id} did not become ready within timeout"
    end

    case Coordinator.get_state(coordinator_id) do
      %{all_games_ready?: true} ->
        :ok

      _ ->
        Process.sleep(@ready_poll_interval_ms)
        wait_ready(coordinator_id, retries_left - 1)
    end
  end
end
