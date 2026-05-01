defmodule PokerMind.Engine.Match.SupervisorTest do
  use ExUnit.Case, async: true

  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor
  alias PokerMindWeb.MatchSupport

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

    test "start_match_suite/3 accepts custom num_games" do
      suite_id = UUID.uuid4()
      num_games = 3

      assert {:ok, pid, ^suite_id} =
               MatchSupervisor.start_match_suite(suite_id, ["stine"], num_games)

      on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

      children = Supervisor.which_children(pid)
      # 1 coordinator + num_games
      assert length(children) == num_games + 1
    end

    test "start_match_suite/3 returns error when suite with same id already exists" do
      suite_id = UUID.uuid4()

      assert {:ok, _pid, ^suite_id} = MatchSupervisor.start_match_suite(suite_id, ["stine"])
      on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

      assert {:error, {:already_started, _pid}} =
               MatchSupervisor.start_match_suite(suite_id, ["stine"])
    end

    test "all_match_suites/0 returns a map of suite_id to players" do
      suite1_id = UUID.uuid4()
      suite2_id = UUID.uuid4()
      players1 = ["rolf", "stine"]
      players2 = ["asbjørn"]

      {:ok, _, ^suite1_id} = MatchSupport.start_match_suite!(suite1_id, players1)
      {:ok, _, ^suite2_id} = MatchSupport.start_match_suite!(suite2_id, players2)

      on_exit(fn ->
        MatchSupervisor.close_match_suite(suite1_id)
        MatchSupervisor.close_match_suite(suite2_id)
      end)

      suites = MatchSupervisor.all_match_suites()
      assert suites[suite1_id] == players1
      assert suites[suite2_id] == players2
    end

    test "all_match_suites/0 does not include closed suites" do
      suite_id = UUID.uuid4()

      {:ok, _, ^suite_id} = MatchSupport.start_match_suite!(suite_id, ["stine"])

      assert Map.has_key?(MatchSupervisor.all_match_suites(), suite_id)

      :ok = MatchSupervisor.close_match_suite(suite_id)

      refute Map.has_key?(MatchSupervisor.all_match_suites(), suite_id)
    end

    test "close_match_suite/1 properly closes suite and its children" do
      suite_id = UUID.uuid4()
      players = ["rolf", "stine"]

      {:ok, pid, ^suite_id} = MatchSupport.start_match_suite!(suite_id, players)

      assert %{^suite_id => ^players} = MatchSupervisor.all_match_suites()

      children = DynamicSupervisor.which_children(pid)
      assert length(children) == 11

      game_pids = Enum.map(children, fn child -> elem(child, 1) end)

      refs =
        Enum.map(game_pids, fn game_pid -> {game_pid, Process.monitor(game_pid)} end)

      assert :ok = MatchSupervisor.close_match_suite(suite_id)

      refute Process.alive?(pid)

      Enum.each(refs, fn {game_pid, ref} ->
        assert_receive {:DOWN, ^ref, :process, ^game_pid, _reason}, 5_000
      end)
    end

    test "close_match_suite/1 returns error when suite does not exist" do
      non_existing_id = UUID.uuid4()

      assert {:error, :suite_not_found} =
               MatchSupervisor.close_match_suite(non_existing_id)
    end

    test "close_match_suite/1 returns error when called twice for same suite" do
      suite_id = UUID.uuid4()

      {:ok, _, ^suite_id} = MatchSupport.start_match_suite!(suite_id, ["stine"])

      assert :ok = MatchSupervisor.close_match_suite(suite_id)
      assert {:error, :suite_not_found} = MatchSupervisor.close_match_suite(suite_id)
    end
  end
end
