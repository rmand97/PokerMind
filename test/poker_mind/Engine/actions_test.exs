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
    # fetch player
    starting_player_id = init_state.current_player_id
    starting_stack = Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips
    # Perform raise action with valid amount
    new_state =
      Actions.apply_action(init_state, %{type: :raise, player_id: starting_player_id, amount: 2* init_state.highest_raise})

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
    # get starting player
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

    # did call action go through?
    assert Enum.any?(new_state.players, &(&1.id == next_player_id and &1.has_acted))

    # next player has to act
    assert next_player_id != new_state.current_player_id

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

  test "test of validation helper functions", %{state: init_state} do
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

    # reset current bet to test valid raise amounts
    init_state = PlayerState.update_current_bet(init_state, starting_player_id, 0)

    # raise amount equal to 2x highest_raise — apply_action returns the updated state, not :ok
    assert %TableState{} =
             Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               amount: 2 * init_state.highest_raise
             })

    # raise amount more than 2x current bet
    assert %TableState{} =
             Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               amount: 3 * init_state.highest_raise
             })

    player_remaining_chips =
      Enum.find(init_state.players, &(&1.id == starting_player_id)).remaining_chips

    # test error catching in validate_amount
    # raise with amount more than players entire stack
    assert Actions.apply_action(init_state, %{
             type: :raise,
             player_id: starting_player_id,
             amount: 3 * player_remaining_chips
           }) ==
             {:error, "Action requires more chips than player has remaining"}

    # raise amount equal to player stack
    assert %TableState{} =
             Actions.apply_action(init_state, %{
               type: :raise,
               player_id: starting_player_id,
               amount: player_remaining_chips
             })
  end
end
