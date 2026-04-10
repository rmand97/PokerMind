defmodule PokerMind.Engine.Match.CoordinatorTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game
  alias PokerMindWeb.MatchSupport
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  describe "Coordinator Tests" do
    test "newly initialized Coordinator is not ready" do
      coordinator_id = UUID.uuid4()
      num_games = 2

      start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

      assert %{all_games_ready: false, num_games: ^num_games, games: %{}} =
               Coordinator.get_state(coordinator_id)
    end

    test "newly initialized Coordinator is ready when all games are ready" do
      coordinator_id = UUID.uuid4()

      start_supervised!({Coordinator, name: coordinator_id, num_games: 2})

      game1_id = UUID.uuid4()
      Coordinator.register_game_ready(coordinator_id, game1_id, "rolf")
      refute Coordinator.get_state(coordinator_id).all_games_ready

      game2_id = UUID.uuid4()
      Coordinator.register_game_ready(coordinator_id, game2_id, "rolf")
      assert Coordinator.get_state(coordinator_id).all_games_ready
    end

    test "can not call other functions than get_state/1 and register_game_ready/3 untill Coordinator is ready" do
      coordinator_id = UUID.uuid4()
      game_id = UUID.uuid4()
      player = "rolf"
      num_games = 2

      start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

      assert %{} = _game_state = Coordinator.get_state(coordinator_id)
      start_supervised!({Game, name: game_id, players: [player], coordinator_id: coordinator_id})

      assert {:error, :not_ready} = Coordinator.next_games(coordinator_id, player, num_games)
    end

    test "next_games/2 - returns players N next games" do
      suite_id = UUID.uuid4()
      coordinator_id = Coordinator.id(suite_id)
      player = "rolf"
      num_games = 15
      take_amount = 5

      {:ok, _pid, suite_id} = MatchSupport.start_match_suite!(suite_id, [player], num_games)
      on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

      games = Coordinator.next_games(coordinator_id, player, take_amount)

      assert length(games) == 5
    end

    test "next_games/2 - only return players own games" do
      coordinator_id = UUID.uuid4()
      num_games = 15
      take_amount = 5

      start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

      Enum.each(1..num_games, fn num ->
        players =
          if num > take_amount - 1 do
            ["stine"]
          else
            ["rolf"]
          end

        game_id = UUID.uuid4()

        start_supervised!(
          Supervisor.child_spec(
            {Game, name: game_id, players: players, coordinator_id: coordinator_id},
            id: {Game, game_id}
          )
        )
      end)

      games = Coordinator.next_games(coordinator_id, "stine", take_amount)

      assert length(games) == 5
    end
  end
end
