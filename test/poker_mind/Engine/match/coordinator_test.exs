defmodule PokerMind.Engine.Match.CoordinatorTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMindWeb.MatchSupport
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "Coordinator Tests" do
    test "newly initialized Coordinator is not ready" do
      coordinator_id = "S1-Coordinator"
      num_games = 2

      start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

      assert %{all_games_ready: false, num_games: ^num_games, games: %{}} =
               Coordinator.get_state(coordinator_id)
    end

    test "newly initialized Coordinator is ready when all games are ready" do
      coordinator_id = "S1-Coordinator"

      start_supervised!({Coordinator, name: coordinator_id, num_games: 2})

      Coordinator.register_game_ready(coordinator_id, "game-1", "rolf")
      refute Coordinator.get_state(coordinator_id).all_games_ready

      Coordinator.register_game_ready(coordinator_id, "game-2", "rolf")
      assert Coordinator.get_state(coordinator_id).all_games_ready
    end

    test "can not call other functions than get_state/1 and register_game_ready/3 untill Coordinator is ready" do
      coordinator_id = "S1-Coordinator"
      player = "rolf"
      num_games = 2

      start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

      assert %{} = _game_state = Coordinator.get_state(coordinator_id)
      assert :ok = Coordinator.register_game_ready(coordinator_id, "game-1", player)

      assert {:error, :not_ready} = Coordinator.next_games(coordinator_id, player, num_games)
    end

    # Fix tests
    # test "next_games/2 - returns players N next games" do
    #   suite_id = "S3"
    #   coordinator_id = "S1-Coordinator"
    #   player = "rolf"
    #   num_games = 15
    #   take_amount = 5

    #   {:ok, _pid, suite_id} = MatchSupport.start_match_suite!(suite_id, [player], num_games)
    #   on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    #   games = Coordinator.next_games(coordinator_id, player, take_amount)

    #   assert length(games) == 5
    # end

    # test "next_games/2 - only return players own games" do
    #   coordinator_id = "S1-Coordinator"
    #   player = "rolf"
    #   num_games = 15
    #   take_amount = 5

    #   start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

    #   Enum.each(1..num_games, fn num ->
    #     player =
    #       if num > take_amount - 1 do
    #         "stine"
    #       else
    #         player
    #       end

    #     :ok = Coordinator.register_game_ready(coordinator_id, "game-#{num}", player)
    #   end)

    #   {games, _} = Coordinator.next_games(coordinator_id, player, take_amount)

    #   assert length(games) == 4
    # end
  end
end
