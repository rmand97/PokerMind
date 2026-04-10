defmodule PokerMind.Engine.TableStateTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState

  setup do
    players =
      [
        "stine",
        "rolf",
        "asbjørn",
        "simon"
      ]

    %{state: TableState.init(TableState.new("123"), players)}
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
    assert Enum.sort(player1.current_hand) != Enum.sort(player2.current_hand)

    # Check that dealt cards have been removed from the deck
    dealt_cards = Enum.flat_map(state.players, fn player -> player.current_hand end)

    for card <- dealt_cards do
      assert !Enum.member?(state.deck, card)
    end
  end

  test "set_blinds/1 - more than 2 players, a player is chosen as small blind and another as current player",
       %{
         state: state
       } do
    assert Enum.any?(state.players, fn player -> player.id == state.small_blind_id end)
    assert Enum.any?(state.players, fn player -> player.id == state.current_player_id end)
    assert state.small_blind_id != state.current_player_id
  end

  test "set_blinds/1 - exactly 2 players, a player is chosen as both small blind and current player" do
    players =
      [
        "stine",
        "rolf"
      ]

    state = TableState.init(TableState.new("123"), players)

    assert Enum.any?(state.players, fn player -> player.id == state.small_blind_id end)
    assert Enum.any?(state.players, fn player -> player.id == state.current_player_id end)
    assert state.small_blind_id == state.current_player_id
  end

  test "advance_player/2 - current player becomes next player in the list", %{
    state: state
  } do
    player_idx_0 = Enum.at(state.players, 0)

    new_state =
      state
      |> Map.put(:current_player_id, player_idx_0.id)
      |> TableState.advance_player()

    assert Enum.find_index(new_state.players, fn p -> p.id == new_state.current_player_id end) ==
             1
  end

  test "advance_player/2 - current player becomes first player in the list if the player before was last in the list",
       %{
         state: state
       } do
    player_idx_last = Enum.at(state.players, length(state.players) - 1)

    new_state =
      state
      |> Map.put(:current_player_id, player_idx_last.id)
      |> TableState.advance_player()

    assert Enum.find_index(new_state.players, fn p -> p.id == new_state.current_player_id end) ==
             0
  end

  test "advance_phase/2 - valid transition from pre_flop to flop", %{
    state: state
  } do
    assert %{phase: :flop} = TableState.advance_phase(state, :flop)
  end

  test "advance_phase/2 - invalid transition from pre_flop to river", %{
    state: state
  } do
    assert {:error, new_state} = TableState.advance_phase(state, :river)
    assert new_state == {:invalid_transition, :pre_flop, :river}
  end
end
