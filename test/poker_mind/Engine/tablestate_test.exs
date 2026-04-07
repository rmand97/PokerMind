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

  test "set_blinds/1 - more than 2 players, a player is chosen as small blind and another as current player",
       %{
         state: state
       } do
    assert Enum.member?(state.players, state.small_blind)
    assert Enum.member?(state.players, state.current_player)
    assert state.small_blind != state.current_player
  end

  test "set_blinds/1 - exactly 2 players, a player is chosen as both small blind and current player" do
    players =
      [
        %{name: "stine", stack_size: 100_000, cards: []},
        %{name: "rolf", stack_size: 100_000, cards: []}
      ]

    state = TableState.init(TableState.new(), players)

    assert Enum.member?(state.players, state.small_blind)
    assert Enum.member?(state.players, state.current_player)
    assert state.small_blind == state.current_player
  end

  test "advance_player/2 - current player becomes next player in the list", %{
    state: state
  } do
    player_idx_0 = Enum.at(state.players, 0)

    new_state =
      state
      |> Map.put(:current_player, player_idx_0)
      |> TableState.advance_player()

    assert Enum.find_index(new_state.players, fn p -> p == new_state.current_player end) == 1
  end

  test "advance_player/2 - current player becomes first player in the list if the player before was last in the list",
       %{
         state: state
       } do
    player_idx_last = Enum.at(state.players, length(state.players) - 1)

    new_state =
      state
      |> Map.put(:current_player, player_idx_last)
      |> TableState.advance_player()

    assert Enum.find_index(new_state.players, fn p -> p == new_state.current_player end) == 0
  end
end
