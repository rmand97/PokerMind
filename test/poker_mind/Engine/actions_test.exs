defmodule PokerMind.Engine.ActionsTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
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

  # test "Call action", %{state: init_state} do
  #   # get current player
  #   # apply call action to current player

  #   # Pot size larger/ should be blinds + call
  #   # Player stack smaller

  #   # new current player
  #   # pre player still "active"
  # end

  test "check action", %{state: init_state} do
    starting_player_id = init_state.current_player_id

    state = TableState.add_to_pot(init_state, starting_player_id, 100)
    new_state = Actions.apply_action(state, %{type: :check, player_id: starting_player_id})

    assert Enum.any?(new_state.players, &(&1.id == starting_player_id and &1.has_acted))
    assert starting_player_id != new_state.current_player_id

    # check that starting player is still :active_in_hand
    assert Enum.any?(
             new_state.players,
             &(&1.id == starting_player_id and &1.state == :active_in_hand)
           )

    assert new_state.pot == 100
  end

  test "all players :check and we go to flop phase", %{state: init_state} do
    num_player = length(init_state.players)
    # all players check
    updated_state =
      Enum.reduce(1..num_player, init_state, fn _, state ->
        current_player_id = state.current_player_id
        # add to pot just to make sure they can check
        state = TableState.add_to_pot(state, current_player_id, 100)

        new_state = Actions.apply_action(state, %{type: :check, player_id: current_player_id})
        new_state
      end)

    assert Enum.all?(updated_state.players, &(not &1.has_acted))
    assert updated_state.phase == :flop
    assert updated_state.pot == 400
  end

  # test "raise action", %{state: init_state} do
  #   # get current player
  #   # apply raise action to current player

  #   # Pot size larger/ should be prev + raise
  #   # Player stack smaller diff = raise

  #   # new current player
  #   # pre player still "active"
  #   # next player cant check ie. current_raise updated with raise amount
  # end
end
