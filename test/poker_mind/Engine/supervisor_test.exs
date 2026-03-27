defmodule PokerMind.Engine.SupervisorTest do
  use ExUnit.Case, async: false

  describe "PokerMind.Engine.Supervisor" do
    test "supervisor process is alive" do
      pid = Process.whereis(PokerMind.Engine.Supervisor)
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "supervisor has 2 children" do
      children = Supervisor.which_children(PokerMind.Engine.Supervisor)
      assert length(children) == 2
    end

    test "Registry process is alive" do
      pid = Process.whereis(PokerMind.Engine.Registry)
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "Match.Supervisor process is alive" do
      pid = Process.whereis(PokerMind.Engine.Match.Supervisor)
      assert pid != nil
      assert Process.alive?(pid)
    end
  end
end
