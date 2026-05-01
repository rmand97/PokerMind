defmodule PokerMindWeb.GameFlowTest do
  @moduledoc """
  User-flow tests that drive gameplay through the HTTP API the way a real
  client would: start a suite, poll GET /api/next_games to discover whose
  turn it is, POST /api/action to act, then poll again.

  These tests verify the request/response contract and state transitions
  a client depends on — without caring who wins.
  """

  use PokerMindWeb.ConnCase, async: true

  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp create_suite(conn, players, num_games \\ 1) do
    json =
      conn
      |> post("/api/start_suite", %{"players" => players, "num_games" => num_games})
      |> json_response(200)

    suite_id = json["suite_id"]
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    %{conn: conn, suite_id: suite_id, players: players}
  end

  defp fetch_next_games(ctx, player_id) do
    ctx.conn
    |> get("/api/next_games", %{"player_id" => player_id, "suite_id" => ctx.suite_id})
    |> json_response(200)
  end

  defp perform_action(ctx, player_id, game_id, action, extra \\ %{}) do
    params =
      Map.merge(
        %{"player_id" => player_id, "game_id" => game_id, "action" => action},
        extra
      )

    ctx.conn
    |> post("/api/action", params)
    |> json_response(200)
  end

  defp current_player_from_engine(suite_id, game_num \\ 1) do
    game_id = Game.id(suite_id, game_num)
    Game.get_state(game_id).game.current_player_id
  end

  # Picks a valid simple action for the current player. In preflop the
  # big blind already matches the highest bet, so call is invalid — use
  # check. Otherwise call is safe.
  defp safe_action(suite_id, game_num \\ 1) do
    game_id = Game.id(suite_id, game_num)
    table = Game.get_state(game_id).game
    current = Enum.find(table.players, &(&1.id == table.current_player_id))

    if current.current_bet >= table.highest_raise do
      "check"
    else
      "call"
    end
  end

  # ------------------------------------------------------------------
  # Suite lifecycle
  # ------------------------------------------------------------------

  describe "suite lifecycle flow" do
    test "start suite, verify it appears in /api/suites, then close it", %{conn: conn} do
      start_json =
        conn
        |> post("/api/start_suite", %{"players" => ["stine", "rolf"], "num_games" => 2})
        |> json_response(200)

      suite_id = start_json["suite_id"]
      assert is_binary(suite_id)

      suites_json = conn |> get("/api/suites") |> json_response(200)
      assert Map.has_key?(suites_json, suite_id)
      assert suites_json[suite_id] == ["stine", "rolf"]

      conn |> delete("/api/close_suite", %{"suite_id" => suite_id}) |> json_response(200)

      suites_after = conn |> get("/api/suites") |> json_response(200)
      refute Map.has_key?(suites_after, suite_id)
    end

    test "start suite defaults to 10 games when num_games is omitted", %{conn: conn} do
      json =
        conn
        |> post("/api/start_suite", %{"players" => ["stine", "rolf"]})
        |> json_response(200)

      suite_id = json["suite_id"]
      on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

      coordinator_id = Coordinator.id(suite_id)
      state = Coordinator.get_state(coordinator_id)

      assert state.num_games == 10
      assert map_size(state.games) == 10
    end
  end

  # ------------------------------------------------------------------
  # Two-player flow
  # ------------------------------------------------------------------

  describe "two-player flow" do
    test "only the current player sees the game in next_games", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])

      current = current_player_from_engine(ctx.suite_id)
      other = if current == "stine", do: "rolf", else: "stine"

      current_response = fetch_next_games(ctx, current)
      assert length(current_response["games"]) == 1

      other_response = fetch_next_games(ctx, other)
      assert length(other_response["games"]) == 0
    end

    test "after an action, turn passes to the other player", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])

      current = current_player_from_engine(ctx.suite_id)
      other = if current == "stine", do: "rolf", else: "stine"
      game_id = Game.id(ctx.suite_id, 1)

      action = safe_action(ctx.suite_id)
      perform_action(ctx, current, game_id, action)

      other_response = fetch_next_games(ctx, other)
      assert length(other_response["games"]) == 1
      assert hd(other_response["games"])["current_player_id"] == other

      current_response = fetch_next_games(ctx, current)
      assert length(current_response["games"]) == 0
    end

    test "players can alternate actions through a full betting round", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      game_id = Game.id(ctx.suite_id, 1)

      p1 = current_player_from_engine(ctx.suite_id)
      perform_action(ctx, p1, game_id, safe_action(ctx.suite_id))

      p2 = current_player_from_engine(ctx.suite_id)
      assert p2 != p1
      action_response = perform_action(ctx, p2, game_id, safe_action(ctx.suite_id))

      assert action_response["phase"] != "preflop"
    end

    test "fold ends the hand and game continues or finishes", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      game_id = Game.id(ctx.suite_id, 1)

      current = current_player_from_engine(ctx.suite_id)

      action_response = perform_action(ctx, current, game_id, "fold")

      assert action_response["id"] == game_id
      assert action_response["player"] != nil
    end

    test "raise action with amount advances the game", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      game_id = Game.id(ctx.suite_id, 1)
      current = current_player_from_engine(ctx.suite_id)

      response = perform_action(ctx, current, game_id, "raise", %{"amount" => 300})

      assert response["id"] == game_id
      assert response["pot"] > 0
    end
  end

  # ------------------------------------------------------------------
  # Three-player flow
  # ------------------------------------------------------------------

  describe "three-player flow" do
    test "only the current player sees the game, others see nothing", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf", "asbjørn"])

      current = current_player_from_engine(ctx.suite_id)
      others = Enum.reject(ctx.players, &(&1 == current))

      current_response = fetch_next_games(ctx, current)
      assert length(current_response["games"]) == 1

      Enum.each(others, fn player ->
        response = fetch_next_games(ctx, player)
        assert length(response["games"]) == 0
      end)
    end

    test "turn rotates through all active players", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf", "asbjørn"])
      game_id = Game.id(ctx.suite_id, 1)

      seen_players =
        Enum.reduce(1..3, [], fn _i, seen ->
          current = current_player_from_engine(ctx.suite_id)
          action = safe_action(ctx.suite_id)
          perform_action(ctx, current, game_id, action)
          [current | seen]
        end)

      assert length(Enum.uniq(seen_players)) == 3
    end

    test "a player who folds no longer gets turns", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf", "asbjørn"])
      game_id = Game.id(ctx.suite_id, 1)

      folder = current_player_from_engine(ctx.suite_id)
      perform_action(ctx, folder, game_id, "fold")

      Enum.each(1..4, fn _i ->
        current = current_player_from_engine(ctx.suite_id)
        assert current != folder

        folder_response = fetch_next_games(ctx, folder)
        assert length(folder_response["games"]) == 0

        action = safe_action(ctx.suite_id)
        perform_action(ctx, current, game_id, action)
      end)
    end
  end

  # ------------------------------------------------------------------
  # Multi-game suite flow
  # ------------------------------------------------------------------

  describe "multi-game suite flow" do
    test "current player sees multiple games in next_games", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"], 5)

      current = current_player_from_engine(ctx.suite_id)
      response = fetch_next_games(ctx, current)

      # With 2 players and 5 games, the current player will be first to
      # act in some subset of them. At minimum they should see at least 1.
      assert length(response["games"]) >= 1

      Enum.each(response["games"], fn game ->
        assert game["current_player_id"] == current
        assert game["id"] != nil
      end)
    end

    test "acting in one game does not affect other games' turn ownership", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"], 3)

      current = current_player_from_engine(ctx.suite_id)
      response_before = fetch_next_games(ctx, current)
      games_before = length(response_before["games"])
      assert games_before >= 1

      first_game = hd(response_before["games"])
      action = safe_action(ctx.suite_id)
      perform_action(ctx, current, first_game["id"], action)

      # The acted-on game may have moved to the other player, so count
      # could decrease by 1, but other games should be unaffected.
      response_after = fetch_next_games(ctx, current)
      assert length(response_after["games"]) >= games_before - 1
    end
  end

  # ------------------------------------------------------------------
  # Response shape validation
  # ------------------------------------------------------------------

  describe "response shape validation" do
    test "next_games response has expected top-level keys", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      current = current_player_from_engine(ctx.suite_id)

      response = fetch_next_games(ctx, current)

      assert Map.has_key?(response, "all_games_finished")
      assert Map.has_key?(response, "games")
      assert Map.has_key?(response, "overall_winners")
    end

    test "game in next_games has expected keys", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      current = current_player_from_engine(ctx.suite_id)

      response = fetch_next_games(ctx, current)
      game = hd(response["games"])

      expected_keys =
        ~w(big_blind_amount community_cards current_player_id hands_played
           highest_raise id other_players phase player pot raise_amount
           small_blind_id winner)

      assert Enum.sort(Map.keys(game)) == Enum.sort(expected_keys)
    end

    test "action response has same shape as game in next_games", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      current = current_player_from_engine(ctx.suite_id)
      game_id = Game.id(ctx.suite_id, 1)

      next_games_response = fetch_next_games(ctx, current)
      game_keys = Map.keys(hd(next_games_response["games"])) |> Enum.sort()

      action = safe_action(ctx.suite_id)
      action_response = perform_action(ctx, current, game_id, action)
      action_keys = Map.keys(action_response) |> Enum.sort()

      assert game_keys == action_keys
    end

    test "player object includes current_hand, other_players do not", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      current = current_player_from_engine(ctx.suite_id)
      game_id = Game.id(ctx.suite_id, 1)

      action = safe_action(ctx.suite_id)
      response = perform_action(ctx, current, game_id, action)

      assert Map.has_key?(response["player"], "current_hand")
      assert is_list(response["player"]["current_hand"])
      assert length(response["player"]["current_hand"]) == 2

      Enum.each(response["other_players"], fn other ->
        refute Map.has_key?(other, "current_hand")
      end)
    end

    test "next_games also hides other players' hands", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      current = current_player_from_engine(ctx.suite_id)

      response = fetch_next_games(ctx, current)
      game = hd(response["games"])

      assert Map.has_key?(game["player"], "current_hand")

      Enum.each(game["other_players"], fn other ->
        refute Map.has_key?(other, "current_hand")
      end)
    end
  end

  # ------------------------------------------------------------------
  # Error flows
  # ------------------------------------------------------------------

  describe "start_suite validation errors" do
    test "missing players returns 400", %{conn: conn} do
      response =
        conn
        |> post("/api/start_suite", %{})
        |> json_response(400)

      assert response["error"] =~ "players"
    end

    test "empty players list returns 400", %{conn: conn} do
      response =
        conn
        |> post("/api/start_suite", %{"players" => []})
        |> json_response(400)

      assert response["error"] =~ "empty"
    end

    test "single player returns 400", %{conn: conn} do
      response =
        conn
        |> post("/api/start_suite", %{"players" => ["stine"]})
        |> json_response(400)

      assert response["error"] =~ "1 player"
    end

    test "non-string players returns 400", %{conn: conn} do
      response =
        conn
        |> post("/api/start_suite", %{"players" => [1, 2]})
        |> json_response(400)

      assert response["error"] =~ "strings"
    end

    test "non-integer num_games returns 400", %{conn: conn} do
      response =
        conn
        |> post("/api/start_suite", %{"players" => ["stine", "rolf"], "num_games" => "five"})
        |> json_response(400)

      assert response["error"] =~ "num_games"
    end
  end

  describe "close_suite errors" do
    test "missing id returns 400", %{conn: conn} do
      response =
        conn
        |> delete("/api/close_suite", %{})
        |> json_response(400)

      assert response["error"] =~ "suite_id"
    end

    test "non-existent suite returns 404", %{conn: conn} do
      response =
        conn
        |> delete("/api/close_suite", %{"suite_id" => UUID.uuid4()})
        |> json_response(404)

      assert response["error"] =~ "not found"
    end
  end

  describe "next_games errors" do
    test "missing params returns 400", %{conn: conn} do
      response = conn |> get("/api/next_games") |> json_response(400)
      assert response["error"] =~ "player_id and suite_id are required"
    end

    test "non-existent suite returns 404", %{conn: conn} do
      response =
        conn
        |> get("/api/next_games", %{"player_id" => "stine", "suite_id" => UUID.uuid4()})
        |> json_response(404)

      assert response["error"] != nil
    end

    test "unknown player returns empty games list", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])

      response = fetch_next_games(ctx, "unknown_player")
      assert length(response["games"]) == 0
    end
  end

  describe "action errors" do
    test "missing params returns 400", %{conn: conn} do
      response = conn |> post("/api/action") |> json_response(400)
      assert response["error"] =~ "player_id, game_id and action are required"
    end

    test "non-existent game returns 404", %{conn: conn} do
      response =
        conn
        |> post("/api/action", %{
          "player_id" => "stine",
          "game_id" => UUID.uuid4(),
          "action" => "fold"
        })
        |> json_response(404)

      assert response["error"] =~ "not found"
    end

    test "invalid action type returns 400", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      game_id = Game.id(ctx.suite_id, 1)
      current = current_player_from_engine(ctx.suite_id)

      response =
        ctx.conn
        |> post("/api/action", %{
          "player_id" => current,
          "game_id" => game_id,
          "action" => "bluff"
        })
        |> json_response(400)

      assert response["error"] =~ "not allowed"
    end

    test "wrong player acting returns 400", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      game_id = Game.id(ctx.suite_id, 1)

      current = current_player_from_engine(ctx.suite_id)
      wrong = if current == "stine", do: "rolf", else: "stine"

      response =
        ctx.conn
        |> post("/api/action", %{
          "player_id" => wrong,
          "game_id" => game_id,
          "action" => "call"
        })
        |> json_response(400)

      assert response["error"] != nil
    end

    test "calling when should check returns 400", %{conn: conn} do
      ctx = create_suite(conn, ["stine", "rolf"])
      game_id = Game.id(ctx.suite_id, 1)
      current = current_player_from_engine(ctx.suite_id)

      # Small blind calls to match big blind
      perform_action(ctx, current, game_id, "call")

      # Big blind's bet already matches — call should fail
      next = current_player_from_engine(ctx.suite_id)

      response =
        ctx.conn
        |> post("/api/action", %{
          "player_id" => next,
          "game_id" => game_id,
          "action" => "call"
        })
        |> json_response(400)

      assert response["error"] =~ "check"
    end
  end
end
