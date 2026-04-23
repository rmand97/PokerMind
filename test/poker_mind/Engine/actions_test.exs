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

  test "fold action", %{state: init_state} do
    # get current player
    assert init_state.current_player_id != nil
    player_who_is_folding = init_state.current_player_id
    # assert init_state.small_blind +2  == init_state.current_player_id

    # Check that current player is in players list and "active_in_hand"
    assert Enum.any?(
             init_state.players,
             fn player ->
               player.id == player_who_is_folding and player.state == :active_in_hand
             end
           )

    # apply fold action to current player
    new_state =
      Actions.apply_action(init_state, %{type: :fold, player_id: init_state.current_player_id})

    # Have the player succesfully folded?
    folded_player =
      Enum.find(new_state.players, fn player -> player.id == player_who_is_folding end)

    assert folded_player.state == :inactive_in_hand

    # The other players should remain unaffected
    unchanged_players = Enum.reject(new_state.players, fn p -> p.id == player_who_is_folding end)
    original_others = Enum.reject(init_state.players, fn p -> p.id == player_who_is_folding end)
    assert unchanged_players == original_others

    # Turn has advanced — new current player is not the one who folded
    assert new_state.current_player_id != player_who_is_folding

    # Pot size is unchanged — folding doesn't affect the pot
    assert new_state.pot == init_state.pot
  end

  test "check action", %{state: init_state} do
    starting_player_id = init_state.current_player_id

    # No outstanding bet — checking is valid
    state = %{init_state | highest_raise: 0}
    new_state = Actions.apply_action(state, %{type: :check, player_id: starting_player_id})

    assert Enum.any?(new_state.players, &(&1.id == starting_player_id and &1.has_acted))
    assert starting_player_id != new_state.current_player_id

    # check that starting player is still :active_in_hand
    assert Enum.any?(
             new_state.players,
             &(&1.id == starting_player_id and &1.state == :active_in_hand)
           )

    # checking doesn't add to the pot
    assert new_state.pot == 0
  end

  test "all players :check and we go to flop phase", %{state: init_state} do
    # No outstanding bet means everyone can legitimately check
    state = %{init_state | highest_raise: 0}
    num_player = length(state.players)
    # all players check
    updated_state =
      Enum.reduce(1..num_player, state, fn _, state ->
        new_state =
          Actions.apply_action(state, %{type: :check, player_id: state.current_player_id})

        new_state
      end)

    # all players should have has_acted reset to false for the next betting round
    assert Enum.all?(updated_state.players, &(not &1.has_acted))
    # phase should advance to flop
    assert updated_state.phase == :flop
    # pot should remain unchanged because no bets were made
    assert updated_state.pot == 0
  end

  test "raise action", %{state: init_state} do
    starting_player_id = init_state.current_player_id
    starting_stack = Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips
    # Perform raise action with valid amount
    new_state =
      Actions.apply_action(init_state, %{
        type: :raise,
        player_id: starting_player_id,
        amount: 2 * init_state.highest_raise
      })

    # did action go through?
    assert Enum.any?(new_state.players, &(&1.id == starting_player_id and &1.has_acted))
    # Next player has to act
    assert starting_player_id != new_state.current_player_id

    # check that starting player is still :active_in_hand
    assert Enum.any?(
             new_state.players,
             &(&1.id == starting_player_id and &1.state == :active_in_hand)
           )

    # pot size should be updated with the raise amount
    assert new_state.pot == 2 * init_state.big_blind_amount
    # check that starting player has the correct remaining chips after the raise
    starting_player_remaining_chips =
      Enum.find(new_state.players, &(&1.id == starting_player_id)).remaining_chips

    # check that chips were deducted from startingplayer stack
    assert starting_player_remaining_chips == starting_stack - 2 * init_state.big_blind_amount

    # highest raise should be updated
    assert new_state.highest_raise == 2 * init_state.big_blind_amount

    # other players cannot check because they need to match the new highest raise
    assert Actions.apply_action(new_state, %{type: :check, player_id: new_state.current_player_id}) ==
             {:error,
              {:current_bet_too_low,
               "Cannot check because your current bet 0 does not match the required highest raise 200"}}
  end

  test "Call action", %{state: init_state} do
    starting_player_id = init_state.current_player_id
    starting_stack = Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips
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
    assert Enum.any?(
             new_state.players,
             &(&1.id == next_player_id and &1.state == :active_in_hand)
           )

    # pot size should be updated with the call amount
    assert new_state.pot == 2 * init_state.big_blind_amount + init_state.highest_raise

    # check that next player has the correct remaining chips after the call
    next_player_remaining_chips =
      Enum.find(new_state.players, &(&1.id == next_player_id)).remaining_chips

    # check that chips were deducted from next player stack
    assert next_player_remaining_chips == starting_stack - init_state.highest_raise
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
    assert Enum.any?(check_state.players, &(&1.id == starting_player_id and &1.has_acted))

    # next player has to act
    assert starting_player_id != check_state.current_player_id
  end

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
    assert Enum.any?(raise_state.players, &(&1.id == starting_player_id and &1.has_acted))

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
    assert Enum.any?(call_state.players, &(&1.id == call_player_id and &1.has_acted))

    # next player has to act
    assert call_player_id != call_state.current_player_id
  end

  test "Test of fold apply_action next player logic", %{state: init_state} do
    starting_player_id = init_state.current_player_id

    fold_state =
      Actions.apply_action(init_state, %{
        type: :fold,
        player_id: starting_player_id
      })

    # did fold action go through?
    assert Enum.any?(fold_state.players, &(&1.id == starting_player_id and &1.has_acted))

    # next player has to act
    assert starting_player_id != fold_state.current_player_id
  end

  test "Test of validate_turn helper function", %{state: init_state} do
    starting_player_id = init_state.current_player_id

    # find id off a different player to test action out of turn    other_player_id =
    out_of_turn = Enum.find(init_state.players, &(&1.id != starting_player_id)).id

    state = %{init_state | highest_raise: 0}

    # action out of turn /no longer starting player's turn
    assert Actions.apply_action(state, %{
             type: :check,
             player_id: out_of_turn
           }) ==
             {:error,
              {:action_out_of_turn, "Awaiting action from player #{state.current_player_id}"}}

    # invalid player id
    assert Actions.apply_action(state, %{
             type: :check,
             player_id: "invalid_player_id"
           }) ==
             {:error, {:invalid_player, "Player not found at the table"}}

    # player not active in hand
    # first fold the next player to make them inactive
    next_player_id = init_state.current_player_id

    new_state =
      Actions.apply_action(state, %{
        type: :fold,
        player_id: next_player_id
      })

    assert Actions.apply_action(new_state, %{
             type: :check,
             player_id: next_player_id
           }) ==
             {:error, {:player_not_active, "Player is not active in the hand"}}

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
    assert Actions.apply_action(new_state, %{
             type: :fold,
             player_id: active_out_of_turn
           }) ==
             {:error,
              {:action_out_of_turn, "Awaiting action from player #{new_state.current_player_id}"}}
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
      Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips

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
      PlayerState.update_current_bet(init_state, starting_player_id, 2 * init_state.highest_raise)

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

  test "all_in action", %{state: init_state} do
    starting_player_id = init_state.current_player_id
    starting_stack = Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips

    all_in_state =
      Actions.apply_action(init_state, %{type: :all_in, player_id: starting_player_id})

    all_in_player = Enum.find(all_in_state.players, &(&1.id == starting_player_id))

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

  test "all_in only adds the delta when player already has chips committed", %{state: init_state} do
    starting_player_id = init_state.current_player_id
    starting_stack = Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips
    already_committed = 50

    # Simulate chips already committed (e.g. posted blind) without mutating the pot
    state_with_commit =
      init_state
      |> PlayerState.deduct_chips(starting_player_id, already_committed)
      |> PlayerState.update_current_bet(starting_player_id, already_committed)

    # Move player all in with the remaining stack (1000 - 50 = 950)
    new_state =
      Actions.apply_action(state_with_commit, %{type: :all_in, player_id: starting_player_id})

    all_in_player = Enum.find(new_state.players, &(&1.id == starting_player_id))

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

    assert Actions.apply_action(init_state, %{type: :all_in, player_id: out_of_turn_id}) ==
             {:error,
              {:action_out_of_turn, "Awaiting action from player #{init_state.current_player_id}"}}

    # invalid player id
    assert Actions.apply_action(init_state, %{type: :all_in, player_id: "invalid_player_id"}) ==
             {:error, {:invalid_player, "Player not found at the table"}}

    # player not active in hand — fold first, then try to go all in as the folded player
    folded_state =
      Actions.apply_action(init_state, %{type: :fold, player_id: starting_player_id})

    assert Actions.apply_action(folded_state, %{type: :all_in, player_id: starting_player_id}) ==
             {:error, {:player_not_active, "Player is not active in the hand"}}
  end
end
