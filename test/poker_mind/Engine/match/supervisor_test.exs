defmodule PokerMind.Engine.Match.SupervisorTest do
  use ExUnit.Case, async: true

  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "PokerMind.Engine.Match.Supervisor" do
    test "can start multiple children" do
      assert {:ok, pid1, id1} = MatchSupervisor.start_match_suite("suite3", ["stine"])
      assert {:ok, pid2, id2} = MatchSupervisor.start_match_suite("suite4", ["rolf"])

      on_exit(fn ->
        MatchSupervisor.close_match_suite(id1)
        MatchSupervisor.close_match_suite(id2)
      end)

      assert pid1 != pid2
      assert id1 != id2
      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
    end
  end
end
