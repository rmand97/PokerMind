defmodule PokerMindWeb.ApiAuthTest do
  use PokerMindWeb.ConnCase, async: true

  test "Can't access endpoint without auth header", %{conn: conn} do
    conn =
      conn
      |> delete_req_header("authorization")
      |> get("/api/next_games", %{"player_id" => "rolf", "suite_id" => UUID.uuid4()})

    assert response(conn, 401)
  end
end
