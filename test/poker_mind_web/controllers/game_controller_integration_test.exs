defmodule PokerMindWeb.GameControllerIntegrationTest do
  @moduledoc """
  End-to-end gameplay tests that drive the engine entirely through the HTTP
  controller (`/api/start_suite`, `/api/action`).

  Mirrors `PokerMind.Engine.IntegrationTest` but goes through the controller.
  Card injection reaches into the `Game` GenServer's state with
  `:sys.replace_state/2` — keeps production code untouched while letting us
  set deterministic hands and community cards.

  One `Game` GenServer plays a full multi-hand poker game, rotating blinds
  internally until only one player has chips. So we start a single-game
  suite (`num_games: 1`) per scenario and stay in that one game throughout.
  """

  use PokerMindWeb.ConnCase, async: true

  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor
  alias PokerMind.Engine.TableState
  alias PokerMindWeb.MatchSupport

  describe "Full game played through the controller" do
    test "Game 1 - heads-up, 3 hands, P2 wins overall", %{conn: conn} do
      players = ["stine", "rolf"]
      ctx = start_suite(conn, players)
      {player1_id, player2_id} = get_players_heads_up(ctx)

      community_cards_hand_1 = [
        {11, :hearts},
        {4, :diamonds},
        {2, :clubs},
        {13, :spades},
        {7, :diamonds}
      ]

      community_cards_hand_2 = [
        {10, :clubs},
        {8, :clubs},
        {3, :clubs},
        {2, :spades},
        {6, :diamonds}
      ]

      community_cards_hand_3 = [
        {13, :hearts},
        {12, :diamonds},
        {5, :clubs},
        {3, :spades},
        {9, :diamonds}
      ]

      ctx
      # Hand 1
      |> set_player_hand(player1_id, [{11, :spades}, {11, :diamonds}])
      |> set_player_hand(player2_id, [{9, :clubs}, {8, :clubs}])
      |> raise_(player1_id, 300)
      |> call(player2_id, 300)
      |> raise_(player1_id, 400)
      |> call(player2_id, 400)
      |> raise_(player1_id, 600)
      |> call(player2_id, 600)
      |> set_community_cards(community_cards_hand_1)
      |> check(player1_id)
      |> check(player2_id)
      # Hand 2
      |> set_player_hand(player1_id, [{1, :diamonds}, {12, :diamonds}])
      |> set_player_hand(player2_id, [{13, :clubs}, {9, :clubs}])
      |> raise_(player2_id, 500)
      |> raise_(player1_id, 1_500)
      |> call(player2_id, 1_500)
      |> set_community_cards(community_cards_hand_2)
      |> check(player2_id)
      |> raise_(player1_id, 2_000)
      |> all_in(player2_id)
      |> call(player1_id, 7_200)
      # Hand 3
      |> set_player_hand(player1_id, [{1, :spades}, {7, :hearts}])
      |> set_player_hand(player2_id, [{13, :diamonds}, {12, :clubs}])
      |> set_community_cards(community_cards_hand_3)
      |> raise_(player1_id, 500)
      |> raise_(player2_id, 1_500)
      |> all_in(player1_id)
      |> call(player2_id, 2_600)
      |> assert_game_winner(player2_id)
    end

    test "Game 2 - heads-up, single hand all-in, P1 wins", %{conn: conn} do
      players = ["stine", "rolf"]
      ctx = start_suite(conn, players)
      {player1_id, player2_id} = get_players_heads_up(ctx)

      community_cards = [
        {1, :hearts},
        {7, :clubs},
        {2, :hearts},
        {11, :spades},
        {9, :clubs}
      ]

      ctx
      |> set_player_hand(player1_id, [{1, :clubs}, {1, :spades}])
      |> set_player_hand(player2_id, [{13, :diamonds}, {12, :spades}])
      |> set_community_cards(community_cards)
      |> all_in(player1_id)
      |> all_in(player2_id)
      |> assert_game_winner(player1_id)
    end

    test "Game 3 - 3 players, multi-hand, P1 wins overall", %{conn: conn} do
      players = ["stine", "rolf", "asbjørn"]
      ctx = start_suite(conn, players)
      {player2_id, player3_id, player1_id} = get_players_three_handed(ctx)

      community_cards_hand_1 = [
        {10, :spades},
        {9, :spades},
        {3, :diamonds},
        {8, :diamonds},
        {2, :clubs}
      ]

      community_cards_hand_2 = [
        {1, :diamonds},
        {5, :clubs},
        {2, :spades},
        {11, :clubs},
        {9, :spades}
      ]

      community_cards_hand_3 = [
        {5, :diamonds},
        {13, :clubs},
        {2, :hearts},
        {11, :spades},
        {7, :diamonds}
      ]

      community_cards_hand_4 = [
        {12, :spades},
        {10, :diamonds},
        {9, :clubs},
        {8, :spades},
        {2, :diamonds}
      ]

      community_cards_hand_5 = [
        {8, :spades},
        {8, :clubs},
        {3, :diamonds},
        {12, :hearts},
        {5, :spades}
      ]

      community_cards_hand_6 = [
        {13, :spades},
        {9, :diamonds},
        {4, :clubs},
        {3, :spades},
        {6, :diamonds}
      ]

      ctx
      # Hand 1: P2 wins with straight
      |> set_player_hand(player1_id, [{5, :diamonds}, {4, :diamonds}])
      |> set_player_hand(player2_id, [{12, :spades}, {11, :spades}])
      |> set_player_hand(player3_id, [{1, :clubs}, {6, :hearts}])
      |> fold(player1_id)
      |> raise_(player2_id, 300)
      |> call(player3_id, 300)
      |> raise_(player2_id, 400)
      |> call(player3_id, 400)
      |> raise_(player2_id, 800)
      |> call(player3_id, 800)
      |> set_community_cards(community_cards_hand_1)
      |> raise_(player2_id, 1_500)
      |> call(player3_id, 1_500)
      # Hand 2: P1 wins with pair of Aces
      |> set_player_hand(player1_id, [{1, :hearts}, {13, :clubs}])
      |> set_player_hand(player2_id, [{13, :hearts}, {3, :diamonds}])
      |> set_player_hand(player3_id, [{7, :clubs}, {6, :spades}])
      |> fold(player2_id)
      |> raise_(player3_id, 400)
      |> raise_(player1_id, 1_200)
      |> call(player3_id, 1_200)
      |> check(player3_id)
      |> raise_(player1_id, 1_500)
      |> call(player3_id, 1_500)
      |> check(player3_id)
      |> raise_(player1_id, 3_600)
      |> call(player3_id, 3_600)
      |> set_community_cards(community_cards_hand_2)
      |> check(player3_id)
      |> check(player1_id)
      # Hand 3: P3 wins with trip Fives
      |> set_player_hand(player1_id, [{12, :diamonds}, {8, :spades}])
      |> set_player_hand(player2_id, [{9, :spades}, {4, :clubs}])
      |> set_player_hand(player3_id, [{5, :hearts}, {5, :clubs}])
      |> set_community_cards(community_cards_hand_3)
      |> all_in(player3_id)
      |> call(player1_id, 700)
      |> fold(player2_id)
      # Hand 4: P2 wins with straight, P3 eliminated
      |> set_player_hand(player1_id, [{10, :hearts}, {8, :diamonds}])
      |> set_player_hand(player2_id, [{1, :spades}, {11, :diamonds}])
      |> set_player_hand(player3_id, [{13, :clubs}, {6, :hearts}])
      |> set_community_cards(community_cards_hand_4)
      |> fold(player1_id)
      |> raise_(player2_id, 400)
      |> all_in(player3_id)
      |> call(player2_id, 1_500)
      # Hand 5: P1 wins with quad Eights
      |> set_player_hand(player1_id, [{8, :hearts}, {8, :diamonds}])
      |> set_player_hand(player2_id, [{1, :clubs}, {13, :spades}])
      |> call(player1_id, 100)
      |> raise_(player2_id, 500)
      |> raise_(player1_id, 1_500)
      |> call(player2_id, 1_500)
      |> raise_(player1_id, 2_000)
      |> raise_(player2_id, 5_000)
      |> raise_(player1_id, 12_850)
      |> call(player2_id, 12_850)
      |> check(player1_id)
      |> check(player2_id)
      |> set_community_cards(community_cards_hand_5)
      |> check(player1_id)
      |> check(player2_id)
      # Hand 6: P1 wins with pair of Kings, P2 eliminated
      |> set_player_hand(player1_id, [{13, :diamonds}, {7, :spades}])
      |> set_player_hand(player2_id, [{11, :clubs}, {2, :hearts}])
      |> set_community_cards(community_cards_hand_6)
      |> check(player1_id)
      |> assert_game_winner(player1_id)
    end
  end

  # ------------------------------------------------------------------
  # Context + lifecycle helpers
  # ------------------------------------------------------------------

  # The `ctx` threaded through the pipeline carries the conn, suite_id,
  # and game_id. We use a single-game suite per scenario — one Game runs
  # multiple hands until elimination determines the winner.
  defp start_suite(conn, players) do
    suite_id = UUID.uuid4()
    {:ok, _pid, ^suite_id} = MatchSupport.start_match_suite!(suite_id, players, 1)
    on_exit(fn -> MatchSupervisor.close_match_suite(suite_id) end)

    %{
      conn: conn,
      suite_id: suite_id,
      players: players,
      game_id: Game.id(suite_id, 1)
    }
  end

  # ------------------------------------------------------------------
  # Action helpers — each issues a real POST /api/action
  # ------------------------------------------------------------------

  defp raise_(ctx, player_id, amount) do
    post_action(ctx, player_id, %{"action" => "raise", "amount" => amount})
  end

  defp call(ctx, player_id, amount) do
    post_action(ctx, player_id, %{"action" => "call", "amount" => amount})
  end

  defp check(ctx, player_id) do
    post_action(ctx, player_id, %{"action" => "check"})
  end

  defp fold(ctx, player_id) do
    post_action(ctx, player_id, %{"action" => "fold"})
  end

  defp all_in(ctx, player_id) do
    post_action(ctx, player_id, %{"action" => "all_in"})
  end

  # Posts the action and asserts the engine actually advanced. We snapshot
  # a state fingerprint before and after — if the response is 200 but
  # nothing changed, that's a silent no-op and we want to fail loudly with
  # the response body in the message instead of letting the pipe continue.
  defp post_action(ctx, player_id, action) do
    params =
      Map.merge(
        %{"player_id" => player_id, "game_id" => ctx.game_id},
        action
      )

    before = state_fingerprint(ctx)
    response = post(ctx.conn, "/api/action", params)
    body = json_response(response, 200)
    after_ = state_fingerprint(ctx)

    assert before != after_, """
    Action did not advance engine state.
    game_id=#{ctx.game_id}
    player_id=#{player_id}
    action=#{inspect(action)}
    response status=#{response.status}
    response body=#{inspect(body)}
    fingerprint before=#{inspect(before)}
    fingerprint after=#{inspect(after_)}
    """

    ctx
  end

  # Coarse-but-sufficient signal: any legal action mutates at least one of
  # these fields. If none change, the action was a no-op.
  defp state_fingerprint(ctx) do
    table = current_table_state(ctx)

    %{
      phase: table.phase,
      pot: table.pot,
      current_player_id: table.current_player_id,
      highest_raise: table.highest_raise,
      hands_played: table.hands_played,
      players:
        Enum.map(table.players, fn p ->
          {p.id, p.state, p.has_acted, p.current_bet, p.remaining_chips}
        end)
    }
  end

  # ------------------------------------------------------------------
  # Card injection — reach into the Game GenServer with :sys.replace_state
  # to deterministically set hands and community cards mid-pipeline.
  # ------------------------------------------------------------------

  defp set_player_hand(ctx, player_id, cards) when is_binary(player_id) and is_list(cards) do
    mapped = Enum.map(cards, fn {rank, suit} -> %{rank: rank, suit: suit} end)

    update_game_state(ctx, fn state ->
      table = state.game
      player = TableState.get_player(table, player_id)
      previous_hand = player.current_hand

      new_table =
        table
        |> Map.put(:deck, table.deck ++ previous_hand)
        |> withdraw_cards_from_deck(cards)
        |> TableState.set_player_value(player_id, :current_hand, mapped)

      %{state | game: new_table}
    end)

    ctx
  end

  defp set_community_cards(ctx, cards) when is_list(cards) do
    mapped = Enum.map(cards, fn {rank, suit} -> %{rank: rank, suit: suit} end)

    update_game_state(ctx, fn state ->
      table = state.game
      previous = table.community_cards

      new_table =
        table
        |> Map.put(:deck, table.deck ++ previous)
        |> withdraw_cards_from_deck(cards)
        |> Map.put(:community_cards, mapped)

      %{state | game: new_table}
    end)

    ctx
  end

  defp withdraw_cards_from_deck(table, cards) do
    Map.update!(table, :deck, fn deck ->
      Enum.reject(deck, fn card ->
        Enum.any?(cards, fn {rank, suit} ->
          card.rank == rank and card.suit == suit
        end)
      end)
    end)
  end

  defp update_game_state(ctx, fun) do
    pid = GenServer.whereis(via_game(ctx.game_id))

    if is_nil(pid) do
      flunk("Game process not found for game_id=#{inspect(ctx.game_id)}")
    end

    :sys.replace_state(pid, fun)
  end

  defp via_game(game_id) do
    PokerMind.Engine.Registry.via(game_id)
  end

  # ------------------------------------------------------------------
  # Player-order discovery (mirrors the engine test's get_players/1).
  # Computed ONCE at the start. Player IDs are stable across hands; the
  # blind rotation that happens internally is encoded into the action
  # sequence the test author writes, not into shifting label bindings.
  # ------------------------------------------------------------------

  defp get_players_heads_up(ctx) do
    rotate_from_small_blind(ctx) |> List.to_tuple()
  end

  defp get_players_three_handed(ctx) do
    rotate_from_small_blind(ctx) |> List.to_tuple()
  end

  defp rotate_from_small_blind(ctx) do
    %TableState{players: players, small_blind_id: sb_id} = current_table_state(ctx)
    sb_index = Enum.find_index(players, fn p -> p.id == sb_id end)
    count = length(players)

    for i <- 0..(count - 1) do
      Enum.at(players, rem(sb_index + i, count)).id
    end
  end

  defp current_table_state(ctx) do
    pid = GenServer.whereis(via_game(ctx.game_id))
    state = :sys.get_state(pid)
    state.game
  end

  # ------------------------------------------------------------------
  # Final assertion — single-game suite, so suite winner == game winner.
  # ------------------------------------------------------------------

  defp assert_game_winner(ctx, expected_winner_id) do
    table = current_table_state(ctx)

    assert table.phase == :game_finished,
           "expected phase=:game_finished, got phase=#{inspect(table.phase)}, " <>
             "winner=#{inspect(table.winner)}, hands_played=#{table.hands_played}"

    assert table.winner == expected_winner_id,
           "expected winner=#{inspect(expected_winner_id)}, got=#{inspect(table.winner)}"

    # Also verify the coordinator was notified (this is what propagates to
    # the JSON `overall_winners` field in /api/next_games).
    coordinator_id = Coordinator.id(ctx.suite_id)
    coordinator_state = Coordinator.get_state(coordinator_id)

    assert coordinator_state.all_games_finished? == true,
           "expected coordinator all_games_finished?, got: #{inspect(coordinator_state)}"

    ctx
  end
end
