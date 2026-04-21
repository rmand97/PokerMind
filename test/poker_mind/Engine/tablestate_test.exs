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

  test "complete_current_player_turn/1 - current players `has_acted` is set to `true`", %{
    state: state
  } do
    current_player_id = state.current_player_id
    current_player = Enum.find(state.players, &(&1.id == current_player_id))
    refute current_player.has_acted

    updated_state = TableState.complete_current_player_turn(state)
    current_player_updated = Enum.find(updated_state.players, &(&1.id == current_player_id))
    assert current_player_updated.has_acted
  end

  test "add_to_pot/3 - amount is deducted from remaining_chips and is added to current_bet and pot",
       %{
         state: state
       } do
    player1 = %{TableState.get_player(state, "stine") | remaining_chips: 100, current_bet: 0}
    player2 = %{TableState.get_player(state, "rolf") | remaining_chips: 100, current_bet: 0}

    # update state with new players (with 100 chips and 0 current bet) to test add_to_pot
    state_new_players =
      state
      |> Map.put(:players, [player1, player2 | Enum.drop(state.players, 4)])

    updated_state =
      state_new_players
      # add_to_pot with 20 chips for each player
      |> TableState.add_to_pot(player2.id, 20)
      |> TableState.add_to_pot(player1.id, 20)
      # add_to_pot with for rolf (so 30 more)
      |> TableState.add_to_pot(player2.id, 50)

    updated_player1 = TableState.get_player(updated_state, player1.id)
    updated_player2 = TableState.get_player(updated_state, player2.id)

    # each player starts with 100 chips
    assert updated_player1.remaining_chips == 80
    assert updated_player1.current_bet == 20

    assert updated_player2.remaining_chips == 50
    assert updated_player2.current_bet == 50

    assert updated_state.pot == 70
  end

  test "compare_cards/2 - returns :lt, :gt, or :eq based on card rank" do
    assert TableState.compare_cards(2, 1) == :lt
    assert TableState.compare_cards(1, 2) == :gt
    assert TableState.compare_cards(1, 1) == :eq
  end

  test "compare_hands/3 - hand1 is better than hand2" do
    player1_hand = [%{rank: 4, suit: :clubs}, %{rank: 5, suit: :diamonds}]
    player2_hand = [%{rank: 11, suit: :hearts}, %{rank: 11, suit: :spades}]

    community_cards = [
      %{rank: 3, suit: :clubs},
      %{rank: 6, suit: :clubs},
      %{rank: 7, suit: :diamonds},
      %{rank: 1, suit: :diamonds},
      %{rank: 1, suit: :clubs}
    ]

    assert TableState.compare_hands(player1_hand, player2_hand, community_cards) == :gt
  end

  test "compare_hands/3 - hand1 and hand2 is equally good" do
    player1_hand = [%{rank: 8, suit: :hearts}, %{rank: 9, suit: :hearts}]
    player2_hand = [%{rank: 3, suit: :diamonds}, %{rank: 4, suit: :diamonds}]

    community_cards = [
      %{rank: 2, suit: :clubs},
      %{rank: 10, suit: :clubs},
      %{rank: 11, suit: :clubs},
      %{rank: 12, suit: :clubs},
      %{rank: 13, suit: :clubs}
    ]

    assert TableState.compare_hands(player1_hand, player2_hand, community_cards) == :eq
  end

  test "compare_hands/3 - hand1 is worse than hand2" do
    player1_hand = [%{rank: 11, suit: :hearts}, %{rank: 11, suit: :spades}]
    player2_hand = [%{rank: 4, suit: :clubs}, %{rank: 5, suit: :diamonds}]

    community_cards = [
      %{rank: 3, suit: :clubs},
      %{rank: 6, suit: :clubs},
      %{rank: 7, suit: :diamonds},
      %{rank: 1, suit: :diamonds},
      %{rank: 1, suit: :clubs}
    ]

    assert TableState.compare_hands(player1_hand, player2_hand, community_cards) == :lt
  end

  test "split_pot/2 - one winner, no leftover chips",
       %{
         state: state
       } do
    new_state =
      state
      |> TableState.set_player_value("simon", :remaining_chips, 0)
      |> TableState.set_player_value("asbjørn", :remaining_chips, 0)
      |> TableState.set_player_value("rolf", :remaining_chips, 0)
      |> Map.put(:pot, 100)

    winners = ["simon"]

    final_state = TableState.split_pot(new_state, winners)

    assert final_state.pot == 0
    assert TableState.get_player(final_state, "simon").remaining_chips == 100
    assert TableState.get_player(final_state, "asbjørn").remaining_chips == 0
    assert TableState.get_player(final_state, "rolf").remaining_chips == 0
  end

  test "split_pot/2 - two winners, one leftover chip for the first winning player",
       %{
         state: state
       } do
    new_state =
      state
      |> TableState.set_player_value("simon", :remaining_chips, 0)
      |> TableState.set_player_value("asbjørn", :remaining_chips, 0)
      |> TableState.set_player_value("rolf", :remaining_chips, 0)
      |> Map.put(:pot, 101)

    winners = ["asbjørn", "rolf"]

    final_state = TableState.split_pot(new_state, winners)

    assert final_state.pot == 0
    assert TableState.get_player(final_state, "simon").remaining_chips == 0
    assert TableState.get_player(final_state, "asbjørn").remaining_chips == 51
    assert TableState.get_player(final_state, "rolf").remaining_chips == 50
  end

  test "split_pot/2 - three winners, two leftover chip, one for the first winning player and one for the second winning player",
       %{
         state: state
       } do
    new_state =
      state
      |> TableState.set_player_value("simon", :remaining_chips, 0)
      |> TableState.set_player_value("asbjørn", :remaining_chips, 0)
      |> TableState.set_player_value("rolf", :remaining_chips, 0)
      |> Map.put(:pot, 101)

    winners = ["simon", "asbjørn", "rolf"]

    final_state = TableState.split_pot(new_state, winners)

    assert final_state.pot == 0
    assert TableState.get_player(final_state, "simon").remaining_chips == 34
    assert TableState.get_player(final_state, "asbjørn").remaining_chips == 34
    assert TableState.get_player(final_state, "rolf").remaining_chips == 33
  end
end
