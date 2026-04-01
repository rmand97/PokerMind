defmodule PokerMind.Engine.TableStateTest do
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

  test "init/2 - players and deck are initialized for a new table", %{state: state} do
    # All 4 players are initialized
    assert Enum.count(state.players) == 4

    # The deck is initialized in which each player has been dealt two cards
    assert Enum.count(state.deck) == 52 - 2 * Enum.count(state.players)
  end

  test "deal_cards/1 - each player gets two seprate cards from the deck", %{state: state} do
    # Check that two players have different cards
    [player1, player2 | _rest] = state.players
    assert Enum.sort(player1.cards) != Enum.sort(player2.cards)

    # Check that dealt cards have been removed from the deck
    dealt_cards = Enum.flat_map(state.players, fn player -> player.cards end)

    for card <- dealt_cards do
      assert !Enum.member?(state.deck, card)
    end
  end
end
