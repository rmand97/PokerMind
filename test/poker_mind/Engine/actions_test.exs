defmodule PokerMind.Engine.ActionsTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState
  alias PokerMind.Engine.Actions

  setup do
    players =
      ["stine", "rolf", "asbjørn", "simon"]

    %{state: TableState.init(TableState.new("Fold_test"), players)}
  end

  test "fold action", %{state: init_state} do
    # get current player
    assert init_state.current_player != nil
    player_who_is_folding = init_state.current_player.id
    # assert init_state.small_blind +2  == init_state.current_player

    # Check that current player is in players list and "active_in_hand"
    assert Enum.any?(
             init_state.players,
             fn player ->
               player.id == player_who_is_folding and player.state == :active_in_hand
             end
           )

    # apply fold action to current player
    new_state = Actions.apply_action(init_state, :fold, init_state.current_player.id)

    # Have the player succesfully folded?
    folded_player =
      Enum.find(new_state.players, fn player -> player.id == player_who_is_folding end)

    assert folded_player.state == :inactive_in_hand

    # The other players should remain unaffected
    unchanged_players = Enum.reject(new_state.players, fn p -> p.id == player_who_is_folding end)
    original_others = Enum.reject(init_state.players, fn p -> p.id == player_who_is_folding end)
    assert unchanged_players == original_others

    # Turn has advanced — new current player is not the one who folded
    assert new_state.current_player != player_who_is_folding

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

  # test "check action", %{state: init_state} do
  #   # get current player
  #   # apply check action to current player

  #   # Pot size the same
  #   # Player stack the same

  #   # new current player
  #   # pre player still "active"
  # end

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
