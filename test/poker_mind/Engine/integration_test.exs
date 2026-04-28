defmodule PokerMind.Engine.IntegrationTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.Actions

  describe "Game 1 (2 players)" do
    test "play 3 hands and verify final outcome" do
      id = UUID.uuid4()
      state = TableState.init(TableState.new(id), ["stine", "rolf"])

      # Initial state
      assert state.phase == :pre_flop
      assert state.big_blind_amount == 100
      assert state.highest_raise == 100

      # Find small_blind player, and set to player 1 and next player to player 2
      player1_id = state.small_blind_id
      player2_id = TableState.find_next_active_player(state, player1_id).id

      # HAND 1
      # Set specific player hands for hand 1
      # Js Jd
      state = set_player_hand(state, player1_id, 11, :spades, 11, :diamonds)
      # 9c 8c
      state = set_player_hand(state, player2_id, 9, :clubs, 8, :clubs)

      # Pre-flop: P1 raises to 300, P2 calls
      state = apply_raise(state, player1_id, 300)
      state = apply_call(state, player2_id, 300)

      # Flop: P1 bets 400, P2 calls
      state = apply_raise(state, player1_id, 400)
      state = apply_call(state, player2_id, 400)

      # Turn: P1 bets 600, P2 calls
      state = apply_raise(state, player1_id, 600)
      state = apply_call(state, player2_id, 600)

      # Set specific community cards before showdown
      state = %{
        state
        | community_cards: [
            %{rank: 11, suit: :hearts},
            %{rank: 4, suit: :diamonds},
            %{rank: 2, suit: :clubs},
            %{rank: 13, suit: :spades},
            %{rank: 7, suit: :diamonds}
          ]
      }

      # River: Both check
      state = apply_check(state, player1_id)
      state = apply_check(state, player2_id)

      # Showdown - P1 wins with trip Jacks
      # P1 should have ~11,300, P2 should have ~8,700
      assert state.phase == :showdown
      assert get_chips(state, player1_id) == 11_300
      assert get_chips(state, player2_id) == 8_700

      # Hand 1 is finished (should be added to handle_showdown/1 in tablestate.ex??)
      state = TableState.advance_phase(state, :hand_finished)

      # Hand 2
      # Set specific player hands for hand 1
      # Ad Qd
      state = set_player_hand(state, player1_id, 1, :diamonds, 12, :diamonds)
      # Kc 9c
      state = set_player_hand(state, player2_id, 13, :clubs, 9, :clubs)

      # Pre-flop: P2 raises to 500, P1 re-raises to 1500, P2 calls
      state = apply_raise(state, player2_id, 500)
      state = apply_raise(state, player1_id, 1_500)
      state = apply_call(state, player2_id, 1_500)

      # Set specific community cards before showdown
      state = %{
        state
        | community_cards: [
            %{rank: 10, suit: :clubs},
            %{rank: 8, suit: :clubs},
            %{rank: 3, suit: :clubs},
            %{rank: 2, suit: :spades},
            %{rank: 6, suit: :diamonds}
          ]
      }

      # Flop: P2 checks, P1 bets 2000, P2 goes all-in for 7200, P1 calls remaining 5200
      state = apply_check(state, player2_id)
      state = apply_raise(state, player1_id, 2_000)
      state = apply_all_in(state, player2_id)
      state = apply_call(state, player1_id, 7200)

      # Showdown - P2 wins with a flush
      # P1 should have ~2,600, P2 should have ~17,400
      assert state.phase == :showdown
      assert get_chips(state, player1_id) == 2_600
      assert get_chips(state, player2_id) == 17_400
    end
  end

  # Helper functions

  defp apply_raise(state, player_id, amount) do
    Actions.apply_action(state, %{type: :raise, player_id: player_id, amount: amount})
  end

  defp apply_call(state, player_id, amount) do
    Actions.apply_action(state, %{type: :call, player_id: player_id, amount: amount})
  end

  defp apply_check(state, player_id) do
    Actions.apply_action(state, %{type: :check, player_id: player_id})
  end

  defp apply_all_in(state, player_id) do
    Actions.apply_action(state, %{type: :all_in, player_id: player_id})
  end

  defp get_chips(state, player_id) do
    TableState.get_player(state, player_id).remaining_chips
  end

  defp set_player_hand(state, player_id, rank1, suit1, rank2, suit2)
       when is_binary(player_id)
       when is_integer(rank1) and is_integer(rank2)
       when is_atom(suit1) and is_atom(suit2) do
    state
    |> TableState.set_player_value(player_id, :current_hand, [
      %{rank: rank1, suit: suit1},
      %{rank: rank2, suit: suit2}
    ])
  end
end
