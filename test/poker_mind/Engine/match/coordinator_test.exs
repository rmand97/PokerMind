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

      start_supervised!(
        {Coordinator, name: coordinator_id, num_games: num_games, players: ["rolf"]}
      )

      assert %{all_games_ready?: false, num_games: ^num_games, games: %{}} =
               Coordinator.get_state(coordinator_id)
    end

    test "newly initialized Coordinator is ready when all games are ready" do
      coordinator_id = UUID.uuid4()

      start_supervised!({Coordinator, name: coordinator_id, num_games: 2, players: ["rolf"]})

      game1_id = UUID.uuid4()

      start_supervised!(
        Supervisor.child_spec(
          {Game, name: game1_id, players: ["rolf"], coordinator_id: coordinator_id},
          id: {Game, game1_id}
        )
      )

      refute Coordinator.get_state(coordinator_id).all_games_ready?

      game2_id = UUID.uuid4()

      start_supervised!(
        Supervisor.child_spec(
          {Game, name: game2_id, players: ["rolf"], coordinator_id: coordinator_id},
          id: {Game, game2_id}
        )
      )

      assert Coordinator.get_state(coordinator_id).all_games_ready?
    end

    test "can not call other functions than get_state/1 and register_game_ready/3 untill Coordinator is ready" do
      coordinator_id = UUID.uuid4()
      game_id = UUID.uuid4()
      player = "rolf"
      num_games = 2

      start_supervised!(
        {Coordinator, name: coordinator_id, num_games: num_games, players: [player]}
      )

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

      start_supervised!(
        {Coordinator, name: coordinator_id, num_games: num_games, players: ["stine", "rolf"]}
      )

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

  test "can mark game as finished" do
    coordinator_id = UUID.uuid4()
    game_id = UUID.uuid4()
    winning_player = "rolf"
    num_games = 1

    start_supervised!(
      {Coordinator, name: coordinator_id, num_games: num_games, players: [winning_player]}
    )

    start_supervised!(
      Supervisor.child_spec(
        {Game, name: game_id, players: [winning_player], coordinator_id: coordinator_id},
        id: {Game, game_id}
      )
    )

    assert :ok = Coordinator.register_game_finished(coordinator_id, game_id, winning_player)
    state = Coordinator.get_state(coordinator_id)
    assert %{^game_id => game} = state.games

    assert game.finished?
    assert is_nil(game.next_player)
    assert game.winner == winning_player
    assert Coordinator.get_state(coordinator_id).all_games_finished?
  end

  describe "ensure_exists" do
    test "next_games/3 returns {:error, :coordinator_not_found} when coordinator does not exist" do
      coordinator_id = UUID.uuid4()
      player = "rolf"

      assert {:error, :coordinator_not_found} = Coordinator.next_games(coordinator_id, player, 5)
    end

    test "register_game_ready/3 returns {:error, :coordinator_not_found} when coordinator does not exist" do
      coordinator_id = UUID.uuid4()
      game_id = UUID.uuid4()

      assert {:error, :coordinator_not_found} =
               Coordinator.register_game_ready(coordinator_id, game_id, "rolf")
    end

    test "register_game_ready/3 returns {:error, :game_not_found} when coordinator exists but game does not" do
      coordinator_id = UUID.uuid4()
      game_id = UUID.uuid4()
      player = "rolf"

      start_supervised!({Coordinator, name: coordinator_id, num_games: 1, players: [player]})

      assert {:error, :game_not_found} =
               Coordinator.register_game_ready(coordinator_id, game_id, "rolf")
    end

    test "register_game_finished/3 returns {:error, :coordinator_not_found} when coordinator does not exist" do
      coordinator_id = UUID.uuid4()
      game_id = UUID.uuid4()

      assert {:error, :coordinator_not_found} =
               Coordinator.register_game_finished(coordinator_id, game_id, "rolf")
    end

    test "register_game_finished/3 returns {:error, :game_not_found} when coordinator exists but game does not" do
      coordinator_id = UUID.uuid4()
      game_id = UUID.uuid4()
      player = "rolf"

      start_supervised!({Coordinator, name: coordinator_id, num_games: 1, players: [player]})

      assert {:error, :game_not_found} =
               Coordinator.register_game_finished(coordinator_id, game_id, player)
    end
  end
end
