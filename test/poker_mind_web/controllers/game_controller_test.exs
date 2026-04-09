defmodule PokerMind.Engine.Match.GameControllerTest do
  use PokerMindWeb.ConnCase
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game

  test "GET /api/next_games with player_id and suite_id", %{conn: conn} do
    suite_id = "S1"
    coordinator_id = Coordinator.id(suite_id)
    num_games = 20
    take_amount = 5

    start_supervised!({Coordinator, name: coordinator_id, num_games: num_games})

    # Register "stine" as starting player for the first 5 games
    # Register "rolf" as starting player for the remaining 15 games
    # Doesn't register "asbjørn" as starting player for any game
    Enum.each(1..num_games, fn num ->
      player =
        if num <= take_amount do
          %{player_id: "stine", remaining_chips: 100}
        else
          %{player_id: "rolf", remaining_chips: 100}
        end

      Coordinator.register_game_ready(
        coordinator_id,
        %{
          id: "game-#{num}",
          players: [
            %{player_id: "stine", remaining_chips: 100},
            %{player_id: "rolf", remaining_chips: 100},
            %{player_id: "asbjørn", remaining_chips: 100}
          ]
        },
        player.player_id
      )
    end)

    # "stine" gets 5 games
    conn = get(conn, "/api/next_games", %{"player_id" => "stine", "suite_id" => suite_id})
    assert %{"data" => games} = json_response(conn, 200)
    assert length(games) == 5

    # "rolf" gets 10 games, as you can only get 10 games
    conn = get(conn, "/api/next_games", %{"player_id" => "rolf", "suite_id" => suite_id})
    assert %{"data" => games} = json_response(conn, 200)
    assert length(games) == 10

    # "asbjørn" gets 0 games
    conn = get(conn, "/api/next_games", %{"player_id" => "asbjørn", "suite_id" => suite_id})
    assert %{"data" => games} = json_response(conn, 200)
    assert length(games) == 0
  end

  test "GET /api/next_games without player_id and suite_id", %{conn: conn} do
    conn = get(conn, "/api/next_games")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id and suite_id are required"
           }
  end

  test "POST /api/action with player_id, game_id and action", %{conn: conn} do
    suite_id = "S2"
    coordinator_id = Coordinator.id(suite_id)
    game_id = "game-1"

    start_supervised!({
      Coordinator,
      name: coordinator_id, num_games: 1
    })

    start_supervised!({
      Game,
      name: game_id, coordinator_id: coordinator_id
    })

    Coordinator.register_game_ready(
      coordinator_id,
      %{
        id: game_id,
        players: [
          %{player_id: "stine", remaining_chips: 100}
        ]
      },
      %{player_id: "stine", remaining_chips: 100}
    )

    conn =
      post(conn, "/api/action", %{
        "player_id" => "stine",
        "game_id" => game_id,
        "action" => "fold"
      })

    assert %{"data" => state} = json_response(conn, 200)
    assert state["coordinator_id"] == coordinator_id
    # TODO: game is empty
    assert state["game"] == %{}
    assert state["id"] == game_id
  end

  test "POST /api/action without player_id, game_id and action", %{conn: conn} do
    conn = post(conn, "/api/action")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id, game_id and action are required"
           }
  end
end
