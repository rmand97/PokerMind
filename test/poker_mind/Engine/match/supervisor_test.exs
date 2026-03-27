defmodule PokerMind.Engine.Match.SupervisorTest do
  use ExUnit.Case, async: false

  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "PokerMind.Engine.Match.Supervisor" do
    test "is alive and running" do
      pid = Process.whereis(MatchSupervisor)
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "start_match_suite/0 returns {:ok, pid, id} with a living pid" do
      assert {:ok, pid, _id} = MatchSupervisor.start_match_suite()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "start_match_suite/0 starts a Supervisor process" do
      assert {:ok, pid, _id} = MatchSupervisor.start_match_suite()

      info = Process.info(pid, :dictionary)
      assert {_, dictionary} = info

      assert Keyword.get(dictionary, :"$initial_call") ==
               {:supervisor, PokerMind.Engine.Match.Suite, 1}
    end

    test "can start multiple children" do
      assert {:ok, pid1, id1} = MatchSupervisor.start_match_suite()
      assert {:ok, pid2, id2} = MatchSupervisor.start_match_suite()

      assert pid1 != pid2
      assert id1 != id2
      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
    end
  end
end
