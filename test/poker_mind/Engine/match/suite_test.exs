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

    test "supports custom num_games" do
      suite_id = UUID.uuid4()
      num_games = 3

      assert {:ok, pid, id} =
               MatchSupervisor.start_match_suite(suite_id, ["stine"], num_games)

      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      children = Supervisor.which_children(pid)
      assert length(children) == num_games + 1

      assert Enum.count(children, fn {{module, _name}, _pid, _type, [module]} ->
               module == Game
             end) == num_games
    end

    test "coordinator is registered in the registry" do
      suite_id = UUID.uuid4()
      assert {:ok, _suite_pid, id} = MatchSupervisor.start_match_suite(suite_id, ["stine"])
      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      assert [{coordinator_pid, :coordinator}] =
               Registry.lookup(PokerMind.Engine.Registry, Coordinator.id(id))

      assert is_pid(coordinator_pid)
      assert Process.alive?(coordinator_pid)
    end

    test "suite itself is registered in the registry" do
      suite_id = UUID.uuid4()
      assert {:ok, suite_pid, id} = MatchSupervisor.start_match_suite(suite_id, ["stine"])
      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      assert [{^suite_pid, :suite}] =
               Registry.lookup(PokerMind.Engine.Registry, id)
    end

    test "all games are registered in the registry with correct ids" do
      suite_id = UUID.uuid4()
      num_games = 5

      assert {:ok, _pid, id} =
               MatchSupervisor.start_match_suite(suite_id, ["stine"], num_games)

      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      Enum.each(1..num_games, fn num ->
        game_id = Game.id(id, num)

        assert [{game_pid, :game}] =
                 Registry.lookup(PokerMind.Engine.Registry, game_id)

        assert is_pid(game_pid)
        assert Process.alive?(game_pid)
      end)
    end

    test "coordinator reports all games ready after init" do
      suite_id = UUID.uuid4()
      assert {:ok, _pid, id} = MatchSupervisor.start_match_suite(suite_id, ["stine"])
      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      coordinator_id = Coordinator.id(id)
      state = Coordinator.get_state(coordinator_id)

      assert state.all_games_ready?
      assert state.num_games == 10
      assert map_size(state.games) == 10
    end

    test "works with multiple players" do
      suite_id = UUID.uuid4()
      players = ["stine", "rolf", "erik"]
      num_games = 3

      assert {:ok, _pid, id} =
               MatchSupervisor.start_match_suite(suite_id, players, num_games)

      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      coordinator_id = Coordinator.id(id)
      state = Coordinator.get_state(coordinator_id)

      assert state.all_games_ready?
      assert state.players == players
    end

    test "each game has correct players assigned" do
      suite_id = UUID.uuid4()
      players = ["stine", "rolf"]
      num_games = 2

      assert {:ok, _pid, id} =
               MatchSupervisor.start_match_suite(suite_id, players, num_games)

      on_exit(fn -> MatchSupervisor.close_match_suite(id) end)

      Enum.each(1..num_games, fn num ->
        game_id = Game.id(id, num)
        game_state = Game.get_state(game_id)

        player_ids = Enum.map(game_state.game.players, & &1.id)
        assert Enum.sort(player_ids) == Enum.sort(players)
      end)
    end

    test "closing a suite stops all children" do
      suite_id = UUID.uuid4()
      num_games = 3

      assert {:ok, suite_pid, id} =
               MatchSupervisor.start_match_suite(suite_id, ["stine"], num_games)

      coordinator_id = Coordinator.id(id)

      [{coordinator_pid, _}] =
        Registry.lookup(PokerMind.Engine.Registry, coordinator_id)

      game_pids =
        Enum.map(1..num_games, fn num ->
          game_id = Game.id(id, num)
          [{pid, _}] = Registry.lookup(PokerMind.Engine.Registry, game_id)
          pid
        end)

      MatchSupervisor.close_match_suite(id)

      Process.sleep(50)

      refute Process.alive?(suite_pid)
      refute Process.alive?(coordinator_pid)
      Enum.each(game_pids, fn pid -> refute Process.alive?(pid) end)
    end
  end
end
