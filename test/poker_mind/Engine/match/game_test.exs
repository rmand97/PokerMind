defmodule PokerMind.Engine.Match.GameTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Coordinator

  setup do
    suite_id = UUID.uuid4()
    coordinator_id = Coordinator.id(suite_id)
    game_id = Game.id(suite_id, 1)
    player = "stine"

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator, name: coordinator_id, num_games: 1, players: [player]},
        id: {Coordinator, coordinator_id}
      )
    )

    start_supervised!(
      Supervisor.child_spec(
        {Game, name: game_id, players: [player], coordinator_id: coordinator_id},
        id: game_id
      )
    )

    %{
      game_id: game_id
    }
  end

  describe "Game tests" do
    test "get_state/2 - returns gamestate", test_vars do
      # TODO: Change when we have actually state in the Game GenServer
      assert Game.get_state(test_vars.game_id) != nil
    end
  end

  describe "ensure_exists" do
    test "get_state/1 returns {:error, :game_not_found} when game does not exist" do
      non_existing_id = UUID.uuid4()
      assert {:error, :game_not_found} = Game.get_state(non_existing_id)
    end

    test "apply_action/3 returns {:error, :game_not_found} when game does not exist" do
      non_existing_id = UUID.uuid4()
      assert {:error, :game_not_found} = Game.apply_action(non_existing_id, "fold", "stine")
    end
  end
end
