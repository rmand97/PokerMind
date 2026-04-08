defmodule PokerMind.Engine.Match.GameControllerTest do
  use PokerMindWeb.ConnCase

  test "GET /api/next_games with player_id and suite_id", %{conn: conn} do
    conn = get(conn, "/api/next_games", %{"player_id" => "stine", "suite_id" => "123"})
    assert json_response(conn, 200) == %{"data" => "games"}
  end

  test "GET /api/next_games without player_id and suite_id", %{conn: conn} do
    conn = get(conn, "/api/next_games")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id and suite_id are required"
           }
  end

  test "POST /api/action with player_id, game_id and action", %{conn: conn} do
    conn =
      post(conn, "/api/action", %{"player_id" => "stine", "game_id" => "123", "action" => "fold"})

    assert json_response(conn, 200) == %{"data" => "ok"}
  end

  test "POST /api/action without player_id, game_id and action", %{conn: conn} do
    conn = post(conn, "/api/action")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id, game_id and action are required"
           }
  end
end
