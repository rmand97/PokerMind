defmodule PokerMind.Engine.Match.GameControllerTest do
  use PokerMindWeb.ConnCase, async: true
  alias PokerMind.Engine.Match.Game
  alias PokerMindWeb.MatchSupport
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

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
             "has_acted",
             "id",
             "player_state",
             "remaining_chips"
           ]

    assert Map.keys(state["game"]["player"]) == [
             "current_hand",
             "has_acted",
             "id",
             "player_state",
             "remaining_chips"
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
end
