defmodule PokerMind.Engine.Match.SuiteTest do
  use ExUnit.Case, async: false

  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "PokerMind.Engine.Match.Suite" do
    test "has 3 children (1 coordinator + 2 games)" do
      assert {:ok, pid, _id} = MatchSupervisor.start_match_suite()

      children = Supervisor.which_children(pid)
      assert length(children) == 3
    end

    test "coordinator is registered in the registry" do
      assert {:ok, _suite_pid, id} = MatchSupervisor.start_match_suite()

      assert [{coordinator_pid, nil}] =
               Registry.lookup(PokerMind.Engine.Registry, "S#{id}-Coordinator")

      assert is_pid(coordinator_pid)
      assert Process.alive?(coordinator_pid)
    end

    test "game processes are started as workers" do
      assert {:ok, _suite_pid, id} = MatchSupervisor.start_match_suite()

      assert [{g0_pid, nil}] = Registry.lookup(PokerMind.Engine.Registry, "S#{id}-G0")
      assert [{g1_pid, nil}] = Registry.lookup(PokerMind.Engine.Registry, "S#{id}-G1")

      assert is_pid(g0_pid)
      assert is_pid(g1_pid)
      assert Process.alive?(g0_pid)
      assert Process.alive?(g1_pid)
      assert g0_pid != g1_pid
    end
  end
end
