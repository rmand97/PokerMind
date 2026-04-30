defmodule PokerMind.Engine.Match.GameControllerTest do
  use PokerMindWeb.ConnCase, async: true
  import OpenApiSpex.TestAssertions
  alias PokerMind.Engine.Match.Game
  alias PokerMindWeb.MatchSupport
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor
  alias PokerMind.Engine.Match.Coordinator

  test "GET /api/next_games with player_id and suite_id", %{conn: conn} do
    suite_id = UUID.uuid4()
    num_games = 10
    players = ["rolf"]

    {:ok, _pid, suite_id} = MatchSupport.start_match_suite!(suite_id, players, num_games)
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    # "stine" gets 10 games
    conn = get(conn, "/api/next_games", %{"player_id" => "rolf", "suite_id" => suite_id})
    assert %{"data" => games} = json_response(conn, 200)
    assert length(games) == 10
  end

  test "GET /api/next_games without player_id and suite_id", %{conn: conn} do
    conn = get(conn, "/api/next_games")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id and suite_id are required"
           }
  end

  test "GET /api/next_games with non-existent suite_id returns 404", %{conn: conn} do
    conn = get(conn, "/api/next_games", %{"player_id" => "rolf", "suite_id" => UUID.uuid4()})

    assert json_response(conn, :not_found) == %{"error" => "coordinator not found"}
  end

  test "POST /api/action with player_id, game_id and action", %{conn: conn} do
    suite_id = UUID.uuid4()
    game_id = Game.id(suite_id, 1)

    players = [
      "stine",
      "rolf",
      "asbjørn",
      "simon"
    ]

    {:ok, _pid, suite_id} = MatchSupport.start_match_suite!(suite_id, players, 1)
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    conn =
      post(conn, "/api/action", %{
        "player_id" => "stine",
        "game_id" => game_id,
        "action" => "fold"
      })

    assert %{"data" => state} = json_response(conn, 200)

    assert Map.keys(state["game"]) == [
             "community_cards",
             "current_player_id",
             "highest_raise",
             "id",
             "other_players",
             "phase",
             "player",
             "pot"
           ]

    assert Map.keys(hd(state["game"]["other_players"])) == [
             "current_bet",
             "has_acted",
             "id",
             "remaining_chips",
             "state"
           ]

    assert Map.keys(state["game"]["player"]) == [
             "current_bet",
             "current_hand",
             "has_acted",
             "id",
             "remaining_chips",
             "state"
           ]

    assert state["id"] == game_id
  end

  test "GET /api/suites returns all running suites with their players", %{conn: conn} do
    suite1_id = UUID.uuid4()
    suite2_id = UUID.uuid4()
    players1 = ["rolf", "stine"]
    players2 = ["asbjørn"]

    {:ok, _pid, ^suite1_id} = MatchSupport.start_match_suite!(suite1_id, players1)
    {:ok, _pid, ^suite2_id} = MatchSupport.start_match_suite!(suite2_id, players2)

    on_exit(fn ->
      MatchSupervisor.close_match_suite(suite1_id)
      MatchSupervisor.close_match_suite(suite2_id)
    end)

    conn = get(conn, "/api/suites")
    assert %{"data" => suites} = json_response(conn, 200)
    assert suites[suite1_id] == players1
    assert suites[suite2_id] == players2
  end

  test "POST /api/action with non-existent game_id returns 404", %{conn: conn} do
    conn =
      conn
      |> post("/api/action", %{
        "player_id" => "rolf",
        "game_id" => UUID.uuid4(),
        "action" => "fold"
      })

    assert json_response(conn, :not_found) == %{"error" => "Game not found"}
  end

  test "POST /api/action without player_id, game_id and action", %{conn: conn} do
    conn = post(conn, "/api/action")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id, game_id and action are required"
           }
  end

  test "POST /api/start_suite starts a new suite with given number of games", %{conn: conn} do
    num_games = 3
    players = ["rolf", "stine"]

    json =
      conn
      |> post("/api/start_suite", %{
        "players" => players,
        "num_games" => num_games
      })
      |> json_response(200)

    suite_id = json["suite_id"]
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    assert %{^suite_id => actual_players} = MatchSupervisor.all_match_suites()
    assert players == actual_players

    coordinator_id = Coordinator.id(suite_id)
    assert %{players: ^players, games: games} = Coordinator.get_state(coordinator_id)
    assert length(Map.keys(games)) == num_games
  end

  test "GameController suites produces a SuitesResponse", %{conn: conn} do
    suite1_id = UUID.uuid4()
    players1 = ["rolf", "stine"]

    {:ok, _pid, ^suite1_id} = MatchSupport.start_match_suite!(suite1_id, players1)

    on_exit(fn ->
      MatchSupervisor.close_match_suite(suite1_id)
    end)

    json = get(conn, "/api/suites") |> json_response(200)

    api_spec = PokerMindWeb.ApiSpec.spec()
    assert_schema(json, "SuitesResponse", api_spec)
  end

  test "GameController next_games produces a GameResponse", %{conn: conn} do
    suite_id = UUID.uuid4()
    num_games = 10
    players = ["stine"]

    {:ok, _pid, suite_id} = MatchSupport.start_match_suite!(suite_id, players, num_games)
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    json =
      conn
      |> get("/api/next_games", %{"player_id" => "stine", "suite_id" => suite_id})
      |> json_response(200)

    api_spec = PokerMindWeb.ApiSpec.spec()
    assert_schema(json, "GameResponse", api_spec)
  end

  test "GameController perform_action produces a Game", %{conn: conn} do
    suite_id = UUID.uuid4()
    game_id = Game.id(suite_id, 1)
    num_games = 10
    players = ["stine"]

    {:ok, _pid, suite_id} = MatchSupport.start_match_suite!(suite_id, players, num_games)
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    json =
      conn
      |> post("/api/action", %{
        "player_id" => "stine",
        "game_id" => game_id,
        "action" => "fold"
      })
      |> json_response(200)

    api_spec = PokerMindWeb.ApiSpec.spec()
    assert_schema(json, "Game", api_spec)
  end

  test "GameController start_suite produces a Start Suite Response", %{conn: conn} do
    num_games = 5

    json =
      conn
      |> post("/api/start_suite", %{
        "players" => ["rolf", "stine"],
        "num_games" => num_games
      })
      |> json_response(200)

    suite_id = json["suite_id"]
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    api_spec = PokerMindWeb.ApiSpec.spec()
    assert_schema(json, "Start Suite Response", api_spec)
  end
end
