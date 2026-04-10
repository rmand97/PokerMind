defmodule PokerMind.Engine.Match.GameTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Coordinator

  setup do
    coordinator_id = "coordinator"
    suite_id = "s1"
    game_id = Game.id(suite_id, 1)

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator, name: coordinator_id, num_games: 1},
        id: {Coordinator, coordinator_id}
      )
    )

    start_supervised!(
      Supervisor.child_spec(
        {Game, name: game_id, players: ["stine"], coordinator_id: coordinator_id},
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
end
