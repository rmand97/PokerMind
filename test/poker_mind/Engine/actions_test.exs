defmodule PokerMind.Engine.ActionsTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState
  alias PokerMind.Engine.Actions

  setup do
    players =
      ["stine", "rolf", "asbjørn", "simon"]

    id = UUID.uuid4()
    %{state: TableState.init(TableState.new(id), players)}
  end

  describe "apply_action :fold" do
    @describetag :fold
    test "fold action", %{state: init_state} do
      # get current player
      assert init_state.current_player_id != nil
      player_who_is_folding = init_state.current_player_id
      # assert init_state.small_blind +2  == init_state.current_player_id

      # Check that current player is in players list and "active_in_hand" before folding
      assert TableState.get_player(init_state, player_who_is_folding).state == :active_in_hand

      # apply fold action to current player
      new_state =
        Actions.apply_action(init_state, %{type: :fold, player_id: init_state.current_player_id})

      # Have the player succesfully folded?
      folded_player = TableState.get_player(new_state, player_who_is_folding)

      assert folded_player.state == :inactive_in_hand

      # The other players should remain unaffected
      unchanged_players =
        Enum.reject(new_state.players, fn p -> p.id == player_who_is_folding end)

      original_others = Enum.reject(init_state.players, fn p -> p.id == player_who_is_folding end)
      assert unchanged_players == original_others

      # Turn has advanced — new current player is not the one who folded
      assert new_state.current_player_id != player_who_is_folding

      # Pot size is unchanged — folding doesn't affect the pot
      assert new_state.pot == init_state.pot
    end

    test "Test of fold apply_action next player logic", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      fold_state =
        Actions.apply_action(init_state, %{
          type: :fold,
          player_id: starting_player_id
        })

      # did fold action go through?
      assert TableState.get_player(fold_state, starting_player_id).has_acted

      # next player has to act
      assert starting_player_id != fold_state.current_player_id
    end
  end

  describe "apply_action :check" do
    @describetag :check
    test "check action", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      # No outstanding bet — checking is valid
      state = %{init_state | highest_raise: 0}
      new_state = Actions.apply_action(state, %{type: :check, player_id: starting_player_id})

      assert TableState.get_player(new_state, starting_player_id).has_acted
      assert starting_player_id != new_state.current_player_id

      # check that starting player is still :active_in_hand
      assert TableState.get_player(new_state, starting_player_id).state == :active_in_hand

      # checking doesn't add to the pot
      assert new_state.pot == state.pot
    end

    test "Test of check apply_action next player logic", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      check_state = %{init_state | highest_raise: 0}

      check_state =
        Actions.apply_action(check_state, %{
          type: :check,
          player_id: starting_player_id
        })

      # did check action go through?
      assert TableState.get_player(check_state, starting_player_id).has_acted

      # next player has to act
      assert starting_player_id != check_state.current_player_id
    end

    test "all players :check and we go to flop phase", %{state: init_state} do
      # No outstanding bet means everyone can legitimately check
      state = %{init_state | highest_raise: 0}
      num_player = length(state.players)
      # reset every players current_bet, as some have been incremented when setting blinds
      reset_current_bet_state =
        Enum.reduce(state.players, state, fn player, current_state ->
          PlayerState.update_current_bet(current_state, player.id, 0)
        end)

      # all players check
      updated_state =
        Enum.reduce(1..num_player, reset_current_bet_state, fn _, state ->
          Actions.apply_action(state, %{type: :check, player_id: state.current_player_id})
        end)

      # all players should have has_acted reset to false for the next betting round
      assert Enum.all?(updated_state.players, &(not &1.has_acted))
      # phase should advance to flop
      assert updated_state.phase == :flop
      # pot should remain unchanged because no bets were made
      assert updated_state.pot == init_state.pot
    end
  end

  describe "apply_action :raise" do
    @describetag :raise
    test "raise action", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      starting_stack = TableState.get_player(init_state, starting_player_id).remaining_chips

      # Perform raise action with valid amount
      new_state =
        Actions.apply_action(init_state, %{
          type: :raise,
          player_id: starting_player_id,
          amount: 2 * init_state.highest_raise
        })

      # did action go through?
      assert TableState.get_player(new_state, starting_player_id).has_acted
      # Next player has to act
      assert starting_player_id != new_state.current_player_id

      # check that starting player is still :active_in_hand
      assert TableState.get_player(new_state, starting_player_id).state == :active_in_hand

      # pot size should be updated with the raise amount
      assert new_state.pot == init_state.pot + 2 * init_state.big_blind_amount
      # check that starting player has the correct remaining chips after the raise

      starting_player_remaining_chips =
        TableState.get_player(new_state, starting_player_id).remaining_chips

      # check that chips were deducted from startingplayer stack
      assert starting_player_remaining_chips == starting_stack - 2 * init_state.big_blind_amount

      # highest raise should be updated
      assert new_state.highest_raise == 2 * init_state.big_blind_amount

      # other players cannot check because they need to match the new highest raise
      assert {:error, {:current_bet_too_low, _}} =
               Actions.apply_action(new_state, %{
                 type: :check,
                 player_id: new_state.current_player_id
               })
    end
  end

  describe "apply_action :call" do
    @describetag :call
    test "Call action", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      starting_stack = TableState.get_player(init_state, starting_player_id).remaining_chips

      # Perform raise action with valid amount
      new_state =
        Actions.apply_action(init_state, %{
          type: :raise,
          player_id: starting_player_id,
          amount: 2 * init_state.highest_raise
        })

      # next player calls
      next_player_id = new_state.current_player_id

      new_state =
        Actions.apply_action(new_state, %{
          type: :call,
          player_id: next_player_id,
          amount: init_state.highest_raise
        })

      # check that the calling player is still :active_in_hand
      assert TableState.get_player(new_state, next_player_id).state == :active_in_hand

      # pot size should be updated with the call amount
      assert new_state.pot ==
               init_state.pot + 2 * init_state.big_blind_amount + init_state.highest_raise

      # check that next player has the correct remaining chips after the call
      next_player_remaining_chips =
        TableState.get_player(new_state, next_player_id).remaining_chips

      # check that chips were deducted from next player stack
      assert next_player_remaining_chips == starting_stack - init_state.highest_raise
    end
  end

  describe "apply_action :all_in" do
    @describetag :all_in
    test "all_in action", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      starting_stack = TableState.get_player(init_state, starting_player_id).remaining_chips

      all_in_state =
        Actions.apply_action(init_state, %{type: :all_in, player_id: starting_player_id})

      all_in_player = TableState.get_player(all_in_state, starting_player_id)

      # player is now :all_in and has acted
      assert all_in_player.state == :all_in
      assert all_in_player.has_acted

      # entire stack was moved to the pot
      assert all_in_player.remaining_chips == 0
      assert all_in_player.current_bet == starting_stack
      assert all_in_state.pot == init_state.pot + starting_stack

      # other players are unaffected
      original_others = Enum.reject(init_state.players, &(&1.id == starting_player_id))
      unchanged_players = Enum.reject(all_in_state.players, &(&1.id == starting_player_id))
      assert unchanged_players == original_others
    end

    test "all_in only adds the delta when player already has chips committed", %{
      state: init_state
    } do
      starting_player_id = init_state.current_player_id

      starting_stack = TableState.get_player(init_state, starting_player_id).remaining_chips

      already_committed = 50

      # Simulate chips already committed (e.g. posted blind) without mutating the pot
      state_with_commit =
        init_state
        |> PlayerState.deduct_chips(starting_player_id, already_committed)
        |> PlayerState.update_current_bet(starting_player_id, already_committed)

      # Move player all in with the remaining stack (1000 - 50 = 950)
      new_state =
        Actions.apply_action(state_with_commit, %{type: :all_in, player_id: starting_player_id})

      all_in_player = TableState.get_player(new_state, starting_player_id)

      # pot grows only by the uncommitted portion of the stack
      assert new_state.pot == init_state.pot + (starting_stack - already_committed)
      assert all_in_player.remaining_chips == 0
      assert all_in_player.current_bet == starting_stack
      assert all_in_player.state == :all_in
    end

    test "all_in validation errors", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      # action out of turn
      out_of_turn_id = Enum.find(init_state.players, &(&1.id != starting_player_id)).id

      assert {:error, {:action_out_of_turn, _}} =
               Actions.apply_action(init_state, %{type: :all_in, player_id: out_of_turn_id})

      # invalid player id
      assert {:error, {:invalid_player, _}} =
               Actions.apply_action(init_state, %{type: :all_in, player_id: "invalid_player_id"})

      # player not active in hand — fold first, then try to go all in as the folded player
      folded_state =
        Actions.apply_action(init_state, %{type: :fold, player_id: starting_player_id})

      assert {:error, {:player_not_active, _}} =
               Actions.apply_action(folded_state, %{type: :all_in, player_id: starting_player_id})
    end

    test "all_in - short all-in (< highest_raise) does not re-open betting",
         %{state: init_state} do
      p1 = init_state.current_player_id

      after_raise =
        Actions.apply_action(init_state, %{type: :raise, player_id: p1, amount: 800})

      p2 = after_raise.current_player_id

      after_call =
        Actions.apply_action(after_raise, %{type: :call, player_id: p2, amount: 800})

      assert TableState.get_player(after_call, p1).has_acted
      assert TableState.get_player(after_call, p2).has_acted

      p3 = after_call.current_player_id
      short_state = TableState.set_player_value(after_call, p3, :remaining_chips, 300)

      final = Actions.apply_action(short_state, %{type: :all_in, player_id: p3})

      # highest_raise unchanged, earlier actors' has_acted preserved
      assert final.highest_raise == 800
      assert TableState.get_player(final, p1).has_acted
      assert TableState.get_player(final, p2).has_acted
      assert TableState.get_player(final, p3).state == :all_in
    end

    test "all_in - matching all-in (== highest_raise) does not re-open betting",
         %{state: init_state} do
      p1 = init_state.current_player_id

      after_raise =
        Actions.apply_action(init_state, %{type: :raise, player_id: p1, amount: 500})

      p2 = after_raise.current_player_id

      after_call =
        Actions.apply_action(after_raise, %{type: :call, player_id: p2, amount: 500})

      p3 = after_call.current_player_id
      # Hard-coding player 3's remaining chips to perform all-in which matches the highest raise
      # - 50 as the third player will always be small blind with 4 players
      matching_state = TableState.set_player_value(after_call, p3, :remaining_chips, 500 - 50)

      final = Actions.apply_action(matching_state, %{type: :all_in, player_id: p3})

      assert final.highest_raise == 500
      assert TableState.get_player(final, p1).has_acted
      assert TableState.get_player(final, p2).has_acted
      assert TableState.get_player(final, p3).state == :all_in
    end

    test "all_in - over-the-top all-in (> highest_raise) updates highest_raise and re-opens betting",
         %{state: init_state} do
      p1 = init_state.current_player_id

      after_raise =
        Actions.apply_action(init_state, %{type: :raise, player_id: p1, amount: 500})

      p2 = after_raise.current_player_id

      after_call =
        Actions.apply_action(after_raise, %{type: :call, player_id: p2, amount: 500})

      assert TableState.get_player(after_call, p1).has_acted
      assert TableState.get_player(after_call, p2).has_acted

      p3 = after_call.current_player_id
      final = Actions.apply_action(after_call, %{type: :all_in, player_id: p3})

      # full stack (1000) goes in over the top of highest_raise 500
      assert final.highest_raise == 1000
      refute TableState.get_player(final, p1).has_acted
      refute TableState.get_player(final, p2).has_acted
      assert TableState.get_player(final, p3).state == :all_in
    end
  end

  describe "validation helper functions" do
    @describetag :validation
    test "Test of validate_turn helper function", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      # find id off a different player to test action out of turn    other_player_id =
      out_of_turn = Enum.find(init_state.players, &(&1.id != starting_player_id)).id

      state = %{init_state | highest_raise: 0}

      # action out of turn /no longer starting player's turn
      assert {:error, {:action_out_of_turn, _}} =
               Actions.apply_action(state, %{
                 type: :check,
                 player_id: out_of_turn
               })

      # invalid player id
      assert {:error, {:invalid_player, _}} =
               Actions.apply_action(state, %{
                 type: :check,
                 player_id: "invalid_player_id"
               })

      # player not active in hand
      # first fold the next player to make them inactive
      next_player_id = init_state.current_player_id

      new_state =
        Actions.apply_action(state, %{
          type: :fold,
          player_id: next_player_id
        })

      assert {:error, {:player_not_active, _}} =
               Actions.apply_action(new_state, %{
                 type: :check,
                 player_id: next_player_id
               })

      # Next player raises to reset betting round
      new_state =
        Actions.apply_action(new_state, %{
          type: :raise,
          player_id: new_state.current_player_id,
          amount: 2 * init_state.big_blind_amount
        })

      active_out_of_turn =
        Enum.find(
          new_state.players,
          &(&1.state != :inactive_in_hand and &1.has_acted != true and
              &1.id != new_state.current_player_id)
        ).id

      # starting_player then acts out of turn
      assert {:error, {:action_out_of_turn, _}} =
               Actions.apply_action(new_state, %{
                 type: :fold,
                 player_id: active_out_of_turn
               })
    end

    test "Test of validate_amount helper function", %{state: init_state} do
      starting_player_id = init_state.current_player_id
      # raise amount equal to 2x highest_raise — apply_action returns the updated state, not :ok
      assert %TableState{} =
               Actions.apply_action(init_state, %{
                 type: :raise,
                 player_id: starting_player_id,
                 amount: 2 * init_state.highest_raise
               })

      # raise amount more than 2x highest_raise
      assert %TableState{} =
               Actions.apply_action(init_state, %{
                 type: :raise,
                 player_id: starting_player_id,
                 amount: 3 * init_state.highest_raise
               })

      player_remaining_chips =
        TableState.get_player(init_state, starting_player_id).remaining_chips

      # raise with amount more than players entire stack
      assert Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               amount: 3 * player_remaining_chips
             }) ==
               {:error,
                "Action requires more chips than player has remaining - if you want to go all in use the all_in action type"}

      # raise amount equal to player stack
      assert Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               amount: player_remaining_chips
             }) ==
               {:error,
                "Action requires all remaining chips - if you want to go all in use the all_in action type"}

      # test call
    end

    test "Test of validate_raise helper function", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      # test error catching in validate_raise
      # raise amount too low
      assert Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               # assumes big blind is 100
               amount: Integer.floor_div(init_state.big_blind_amount, 2)
             }) == {:error, "Not a valid raise - assume bet size too small"}

      # set current bet equal to highest raise to test error catching in validate_raise for raise amount equal to current bet
      init_state =
        PlayerState.update_current_bet(
          init_state,
          starting_player_id,
          2 * init_state.highest_raise
        )

      # raise amount equal to current bet
      assert Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               amount: 2 * init_state.highest_raise
             }) == {:error, "Current_bet = new raise amount - did we already perform this bet?"}

      assert %TableState{} =
               Actions.apply_action(init_state, %{
                 type: :raise,
                 player_id: starting_player_id,
                 amount: 8 * init_state.highest_raise
               })
    end
  end

  describe "apply_action error handling" do
    @describetag :apply_action_error_handling
    test "game_finished and unsupported action errors", %{state: init_state} do
      # game finished
      game_finished_state = %{init_state | phase: :game_finished}
      starting_player_id = init_state.current_player_id

      assert {:error, {:game_is_finished, _}} =
               Actions.apply_action(game_finished_state, %{
                 type: :raise,
                 player_id: starting_player_id,
                 amount: 200
               })

      # unsupported action type
      assert {:error, {:invalid_action, _}} =
               Actions.apply_action(init_state, %{
                 type: :unsupported_action,
                 player_id: starting_player_id
               })
    end
  end

  describe "round transitions" do
    test "Test of raise/ call/ fold apply_action next player logic", %{state: init_state} do
      starting_player_id = init_state.current_player_id

      raise_state = %{init_state | highest_raise: 100}

      raise_state =
        Actions.apply_action(raise_state, %{
          type: :raise,
          player_id: starting_player_id,
          amount: 2 * raise_state.highest_raise
        })

      # did raise action go through?
      assert TableState.get_player(raise_state, starting_player_id).has_acted

      # next player has to act
      assert starting_player_id != raise_state.current_player_id

      call_player_id = raise_state.current_player_id

      call_state =
        Actions.apply_action(raise_state, %{
          type: :call,
          player_id: call_player_id,
          amount: 2 * init_state.highest_raise
        })

      # did call action go through?
      assert TableState.get_player(call_state, call_player_id).has_acted

      # next player has to act
      assert call_player_id != call_state.current_player_id
    end

    test "round transition resets current_bet, has_acted, highest_raise and preserves total_contributed",
         %{state: init_state} do
      p1 = init_state.current_player_id

      raised =
        Actions.apply_action(init_state, %{
          type: :raise,
          player_id: p1,
          amount: 2 * init_state.highest_raise
        })

      # Three remaining players call to close the round
      final =
        Enum.reduce(1..3, raised, fn _, s ->
          Actions.apply_action(s, %{
            type: :call,
            player_id: s.current_player_id,
            amount: 2 * init_state.highest_raise
          })
        end)

      assert final.phase == :flop
      assert final.highest_raise == init_state.big_blind_amount
      assert Enum.all?(final.players, &(&1.current_bet == 0))
      assert Enum.all?(final.players, &(not &1.has_acted))

      assert Enum.all?(
               final.players,
               &(&1.total_contributed == 2 * init_state.big_blind_amount)
             )
    end
  end
end
