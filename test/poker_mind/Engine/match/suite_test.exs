defmodule PokerMind.Engine.Match.SuiteTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "Suite Tests" do
    test "has 11 children (1 coordinator + 10 games)" do
      suite_id = UUID.uuid4()
      assert {:ok, pid, id} = MatchSupervisor.start_match_suite(suite_id, ["stine"])
      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      children = Supervisor.which_children(pid)
      assert length(children) == 11

      assert Enum.count(children, fn {{module, _name}, _pid, _type, [module]} ->
               module == Coordinator
             end) == 1

      assert Enum.count(children, fn {{module, _name}, _pid, _type, [module]} ->
               module == Game
             end) == 10
    end

    test "coordinator is registered in the registry" do
      suite_id = UUID.uuid4()
      assert {:ok, _suite_pid, id} = MatchSupervisor.start_match_suite(suite_id, ["stine"])
      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      assert [{coordinator_pid, nil}] =
               Registry.lookup(PokerMind.Engine.Registry, Coordinator.id(id))

      assert is_pid(coordinator_pid)
      assert Process.alive?(coordinator_pid)
    end
  end
end
