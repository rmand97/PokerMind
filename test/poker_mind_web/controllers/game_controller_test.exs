defmodule PokerMind.Engine.Match.GameControllerTest do
  use PokerMindWeb.ConnCase, async: true
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.TableState.PlayerState
  alias PokerMindWeb.MatchSupport
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  test "GET /api/next_games with player_id and suite_id", %{conn: conn} do
    suite_id = "S1"
    num_games = 10

    players = [
      "rolf"
    ]

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

  test "POST /api/action with player_id, game_id and action", %{conn: conn} do
    suite_id = "S2"
    game_id = Game.id(suite_id, 1)

    players = [
      "stine"
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
    # TODO: game is empty
    # assert state["game"] == %{}
    assert state["id"] == game_id
  end

  test "POST /api/action without player_id, game_id and action", %{conn: conn} do
    conn = post(conn, "/api/action")

    assert json_response(conn, :bad_request) == %{
             "error" => "player_id, game_id and action are required"
           }
  end
end
