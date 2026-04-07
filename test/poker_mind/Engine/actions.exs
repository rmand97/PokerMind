defmodule PokerMind.Engine.ActionsTest do
  alias PokerMind.Engine.TableState
  use ExUnit.Case, async: true

  setup do
    players =
      [
        %{name: "stine", stack_size: 100_000, cards: []},
        %{name: "rolf", stack_size: 100_000, cards: []},
        %{name: "asbjørn", stack_size: 100_000, cards: []},
        %{name: "simon", stack_size: 100_000, cards: []}
      ]

    %{state: TableState.init(TableState.new(), players)}
  end

  test "Call action", %{state: init_state} do
    # get current player
    # apply call action to current player

    # Pot size larger/ should be blinds + call
    # Player stack smaller

    # new current player
    # pre player still "active"
  end

  test "check action", %{state: init_state} do
    # get current player
    # apply check action to current player

    # Pot size the same
    # Player stack the same

    # new current player
    # pre player still "active"
  end

  test "fold action", %{state: init_state} do
    # get current player
    # apply fold action to current player

    # Pot size the same
    # Player the same

    # new current player
    # pre player no longer "active"
  end

  test "raise action", %{state: init_state} do
    # get current player
    # apply raise action to current player

    # Pot size larger/ should be prev + raise
    # Player stack smaller diff = raise

    # new current player
    # pre player still "active"
    # next player cant check ie. current_raise updated with raise amount
  end
end
