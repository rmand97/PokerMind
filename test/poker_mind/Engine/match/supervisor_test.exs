defmodule PokerMind.Engine.Match.SupervisorTest do
  use ExUnit.Case, async: true

  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "PokerMind.Engine.Match.Supervisor" do
    test "can start multiple children" do
      suite1_id = UUID.uuid4()
      suite2_id = UUID.uuid4()

      assert {:ok, pid1, id1} = MatchSupervisor.start_match_suite(suite1_id, ["stine"])
      assert {:ok, pid2, id2} = MatchSupervisor.start_match_suite(suite2_id, ["rolf"])

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
