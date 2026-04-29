defmodule PokerMind.Engine.TableStateTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

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

  # Board A♠ A♥ A♦ A♣ K♠ makes the five community cards the best possible 5-card
  # hand for every player (four aces + K kicker), forcing a tie regardless of hole
  # cards. Used below to exercise pay_pot's odd-chip splitting via distribute_pots.
  defp tied_board do
    [
      %{rank: 1, suit: :spades},
      %{rank: 1, suit: :hearts},
      %{rank: 1, suit: :diamonds},
      %{rank: 1, suit: :clubs},
      %{rank: 13, suit: :spades}
    ]
  end

  defp showdown_state(players, community) do
    %TableState{
      id: "test",
      phase: :showdown,
      players: players,
      pot: Enum.sum(Enum.map(players, & &1.total_contributed)),
      deck: [],
      community_cards: community,
      small_blind_id: "A",
      current_player_id: "A",
      hands_played: 0
    }
  end

  defp showdown_player(id, state, total_contributed, hole) do
    %PlayerState{
      id: id,
      remaining_chips: 0,
      state: state,
      current_bet: total_contributed,
      total_contributed: total_contributed,
      has_acted: true,
      current_hand: hole
    }
  end

  defp pots_state(players_data) do
    players =
      Enum.map(players_data, fn {id, state, total_contributed} ->
        %PlayerState{
          id: id,
          remaining_chips: 0,
          state: state,
          current_bet: 0,
          total_contributed: total_contributed,
          has_acted: false
        }
      end)

    %TableState{
      id: "test",
      phase: :showdown,
      players: players,
      pot: Enum.sum(Enum.map(players, & &1.total_contributed)),
      deck: [],
      community_cards: []
    }
  end

  describe "initialization of a new table" do
    test "init/2 - players and deck are initialized for a new table", %{state: state} do
      # All 4 players are initialized
      assert Enum.count(state.players) == 4

      # The deck is initialized in which each player has been dealt two cards
      assert Enum.count(state.deck) == 52 - 2 * Enum.count(state.players)
    end
  end

  describe "Initialization of a new hand (deal_cards/1 and set_blinds/1)" do
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

    test "set_blinds/2 - more than 2 players, a player is chosen as small blind and another as current player",
         %{
           state: state
         } do
      assert Enum.any?(state.players, fn player -> player.id == state.small_blind_id end)
      assert Enum.any?(state.players, fn player -> player.id == state.current_player_id end)
      assert state.small_blind_id != state.current_player_id
    end

    test "set_blinds/2 - exactly 2 players, a player is chosen as both small blind and current player" do
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

    test "set_blinds/2 - blinds increases to the double every 10 hands",
         %{
           state: state
         } do
      new_state =
        Enum.reduce(1..9, state, fn i, current_state ->
          after_hand_finished =
            current_state
            |> TableState.advance_phase(:showdown)

          # big blind amount stays the same for the first 9 hands
          assert after_hand_finished.hands_played == i
          assert after_hand_finished.big_blind_amount == state.big_blind_amount
          # The same for highest_raise and raise_amount
          assert after_hand_finished.highest_raise == state.highest_raise
          assert after_hand_finished.raise_amount == state.raise_amount
          after_hand_finished
        end)

      final_state =
        new_state
        |> TableState.advance_phase(:showdown)

      # big_blind doubles when 10 hands has been played
      assert final_state.phase == :pre_flop
      assert final_state.big_blind_amount == state.big_blind_amount * 2
      # The same for highest_raise and raise_amount
      assert final_state.highest_raise == state.highest_raise * 2
      assert final_state.raise_amount == state.raise_amount * 2
    end
  end

  describe "advance_player/2" do
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
  end

  describe "advance_phase/2" do
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

    test "advance_phase/2 - deal community_cards, three for flop, one for turn and one for river",
         %{
           state: state
         } do
      flop_phase = TableState.next_phase(state)
      flop_state = TableState.advance_phase(state, flop_phase)

      turn_phase = TableState.next_phase(flop_state)
      turn_state = TableState.advance_phase(flop_state, turn_phase)

      river_phase = TableState.next_phase(turn_state)
      river_state = TableState.advance_phase(turn_state, river_phase)

      assert length(flop_state.community_cards) == 3
      assert length(turn_state.community_cards) == 4
      assert length(river_state.community_cards) == 5
    end

    test "advance_phase/2 - handle showdown with one active player remaining",
         %{
           state: state
         } do
      players = [
        "stine",
        "rolf",
        "asbjørn",
        "simon"
      ]

      new_state =
        Enum.reduce(players, state, fn name, acc ->
          acc
          |> TableState.set_player_value(name, :state, :inactive_in_hand)
          |> TableState.set_player_value(name, :remaining_chips, 0)
          |> TableState.set_player_value(name, :total_contributed, 25)
        end)
        |> TableState.set_player_value("stine", :state, :active_in_hand)
        |> Map.put(:pot, 100)

      next_phase = TableState.next_phase(new_state)
      final_state = TableState.advance_phase(new_state, next_phase)

      assert next_phase == :showdown
      assert final_state.pot == 0
      assert final_state.community_cards == []
      assert TableState.get_player(final_state, "rolf").remaining_chips == 0
      assert TableState.get_player(final_state, "stine").remaining_chips == 100
    end

    test "advance_phase/2 - handle finished and starts a new hand with new small blind and reset players and table",
         %{
           state: state
         } do
      players = [
        "stine",
        "rolf",
        "asbjørn",
        "simon"
      ]

      new_hand_state =
        Enum.reduce(players, state, fn name, current_state ->
          current_state
          |> TableState.set_player_value(name, :state, :inactive_in_hand)
          |> TableState.set_player_value(name, :remaining_chips, 500)
        end)
        |> TableState.set_player_value("stine", :state, :active_in_hand)
        |> Map.put(:pot, 150)
        |> TableState.advance_phase(:showdown)

      # Showdown leaves stine with 200 chips and rest with 50
      for {player, updated_player} <- Enum.zip(state.players, new_hand_state.players) do
        # Make sure we compare the same player
        assert player.id == updated_player.id
        # Current hand has been updated for each player
        assert length(player.current_hand) == length(updated_player.current_hand)
        assert player.current_hand != updated_player.current_hand
        # Current_bet, has_acted and state is reset
        # Current_bet depends on whether the player is chosen as small_blind or big_blind
        assert updated_player.current_bet == 0 or
                 updated_player.current_bet == 50 or
                 updated_player.current_bet == 100

        # Total_contributed depends on whether the player is chosen as small_blind or big_blind
        assert updated_player.total_contributed == 0 or
                 updated_player.total_contributed == 50 or
                 updated_player.total_contributed == 100

        assert updated_player.has_acted == false
        assert updated_player.state == :active_in_hand
      end

      # No winner found yet
      assert new_hand_state.winner == nil
      # New small blind is selected and we start the new hand
      assert state.small_blind_id != new_hand_state.small_blind_id
      assert new_hand_state.phase == :pre_flop
    end

    test "advance_phase/2 - an overall winner has been found for the table",
         %{
           state: state
         } do
      players = [
        "stine",
        "rolf",
        "asbjørn",
        "simon"
      ]

      winner_state =
        Enum.reduce(players, state, fn name, current_state ->
          current_state
          |> TableState.set_player_value(name, :state, :out_of_chips)
          |> TableState.set_player_value(name, :remaining_chips, 0)
          |> TableState.set_player_value(name, :total_contributed, 25)
        end)
        |> TableState.set_player_value("stine", :state, :active_in_hand)
        |> Map.put(:pot, 100)
        |> TableState.advance_phase(:showdown)

      # Showdown leaves stine with 100 chips and rest with 0
      # stine is the winner of the table
      assert winner_state.winner == "stine"
      assert winner_state.phase == :game_finished
    end
  end

  describe "set_current_player_for_phase/1" do
    test "post-flop fallback when small blind is inactive picks next active player",
         %{state: state} do
      # Regression: post-flop the phase starter is the small blind. When the
      # small blind is not :active_in_hand, the fallback used to pass the
      # player struct into find_next_active_player_id/2, which is guarded by
      # is_binary/1 — raising FunctionClauseError.
      result =
        state
        |> Map.put(:phase, :flop)
        |> TableState.set_player_value(state.small_blind_id, :state, :inactive_in_hand)
        |> TableState.set_current_player_for_phase()

      assert result.current_player_id != state.small_blind_id

      assert TableState.get_player(result, result.current_player_id).state ==
               :active_in_hand
    end
  end

  describe "complete_current_player_turn/1" do
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
  end

  describe "add_to_pot/3" do
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

      assert updated_state.pot == state.pot + 70
    end

    test "add_to_pot/3 - if player does not meet required amount to add, add remaining chips and go all in",
         %{state: state} do
      # player 1 gets 50 chips
      player1 = %{TableState.get_player(state, "stine") | remaining_chips: 50, current_bet: 0}
      state_new_players = Map.put(state, :players, [player1 | Enum.drop(state.players, 4)])

      # player 1 becomes big_blind, and has to add 100 chips to the pot
      updated_state =
        state_new_players
        |> TableState.add_to_pot(player1.id, 100)

      updated_player1 = TableState.get_player(updated_state, player1.id)

      # player 1 can only add 50 chips and is now all_in
      assert updated_player1.remaining_chips == 0
      assert updated_player1.state == :all_in
      assert updated_state.pot == state.pot + 50
    end
  end

  describe "Test of compare functions (compare_cards/2 and compare_hands/3)" do
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
  end

  describe "build_pots/1" do
    test "build_pots/1 - two all-ins at different stacks, third covers" do
      state =
        pots_state([
          {"A", :all_in, 50},
          {"B", :all_in, 150},
          {"C", :active_in_hand, 150}
        ])

      assert %{
               pots: [
                 %{amount: 150, eligible_ids: ["A", "B", "C"]},
                 %{amount: 200, eligible_ids: ["B", "C"]}
               ],
               refunds: []
             } = TableState.build_pots(state)
    end

    test "build_pots/1 - uncontested top layer refunded to sole still-in contributor" do
      state =
        pots_state([
          {"A", :all_in, 100},
          {"B", :active_in_hand, 300},
          {"C", :inactive_in_hand, 100}
        ])

      result = TableState.build_pots(state)
      assert [%{amount: 300, eligible_ids: ["A", "B"]}] = result.pots
      assert [{"B", 200}] = result.refunds
    end

    test "build_pots/1 - folded player contributes but is never eligible" do
      state =
        pots_state([
          {"A", :active_in_hand, 200},
          {"B", :active_in_hand, 200},
          {"C", :inactive_in_hand, 200}
        ])

      assert %{
               pots: [%{amount: 600, eligible_ids: ["A", "B"]}],
               refunds: []
             } = TableState.build_pots(state)
    end

    test "build_pots/1 - single still-in player at top layer refunds the excess" do
      state =
        pots_state([
          {"A", :all_in, 100},
          {"B", :active_in_hand, 500}
        ])

      result = TableState.build_pots(state)
      assert [%{amount: 200, eligible_ids: ["A", "B"]}] = result.pots
      assert [{"B", 400}] = result.refunds
    end
  end

  describe "distribute_pots/1" do
    test "distribute_pots/1 - single winner takes the whole pot" do
      community = [
        %{rank: 2, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 5, suit: :hearts},
        %{rank: 9, suit: :clubs},
        %{rank: 12, suit: :diamonds}
      ]

      players = [
        showdown_player("A", :active_in_hand, 50, [
          %{rank: 1, suit: :spades},
          %{rank: 1, suit: :clubs}
        ]),
        showdown_player("B", :active_in_hand, 50, [
          %{rank: 4, suit: :spades},
          %{rank: 8, suit: :clubs}
        ])
      ]

      final = TableState.distribute_pots(showdown_state(players, community))

      assert final.pot == 0
      assert TableState.get_player(final, "A").remaining_chips == 100
      assert TableState.get_player(final, "B").remaining_chips == 0
    end

    test "distribute_pots/1 - two tied winners with one leftover chip goes to the first winner" do
      # Still-in A, B each contribute 500. Folded C contributes 1 extra chip, so the
      # layer-500 pot is 1001 split between two tied winners: 500 + 1 leftover → A=501, B=500.
      players = [
        showdown_player("A", :active_in_hand, 500, [
          %{rank: 2, suit: :spades},
          %{rank: 3, suit: :clubs}
        ]),
        showdown_player("B", :active_in_hand, 500, [
          %{rank: 4, suit: :spades},
          %{rank: 5, suit: :clubs}
        ]),
        showdown_player("C", :out_of_chips, 1, [
          %{rank: 6, suit: :spades},
          %{rank: 7, suit: :clubs}
        ])
      ]

      final = TableState.distribute_pots(showdown_state(players, tied_board()))

      # Final pot is 150 as it is the sum of big_blind and small_blind
      assert final.pot == 150
      assert TableState.get_player(final, "A").remaining_chips == 501 - 100
      assert TableState.get_player(final, "B").remaining_chips == 500 - 50
      assert TableState.get_player(final, "C").remaining_chips == 0
    end

    test "distribute_pots/1 - three tied winners with two leftover chips go to the first two winners" do
      # Still-in A, B, C each contribute 330. Folded D contributes 2 extra chips, so
      # the layer-330 pot is 992 split between three tied winners: 330 + 2 leftover →
      # A=331, B=331, C=330, D=0.
      players = [
        showdown_player("A", :active_in_hand, 330, [
          %{rank: 2, suit: :spades},
          %{rank: 3, suit: :clubs}
        ]),
        showdown_player("B", :active_in_hand, 330, [
          %{rank: 4, suit: :spades},
          %{rank: 5, suit: :clubs}
        ]),
        showdown_player("C", :active_in_hand, 330, [
          %{rank: 6, suit: :spades},
          %{rank: 7, suit: :clubs}
        ]),
        showdown_player("D", :inactive_in_hand, 2, [
          %{rank: 8, suit: :spades},
          %{rank: 9, suit: :clubs}
        ])
      ]

      final = TableState.distribute_pots(showdown_state(players, tied_board()))

      # Final pot is 150 as it is the sum of big_blind and small_blind
      assert final.pot == 150
      assert TableState.get_player(final, "A").remaining_chips == 331
      assert TableState.get_player(final, "B").remaining_chips == 331 - 50
      assert TableState.get_player(final, "C").remaining_chips == 330 - 100
      assert TableState.get_player(final, "D").remaining_chips == 0
    end

    test "distribute_pots/1 - all-in player wins main pot, bigger stack wins side pot" do
      # A all-in 100 with pair of Kings, B all-in 300 with pair of Queens,
      # C all-in 300 with high card. A wins main pot, B wins side pot.
      players = [
        %PlayerState{
          id: "A",
          remaining_chips: 0,
          state: :all_in,
          current_bet: 100,
          total_contributed: 100,
          has_acted: true,
          current_hand: [%{rank: 13, suit: :spades}, %{rank: 13, suit: :clubs}]
        },
        %PlayerState{
          id: "B",
          remaining_chips: 0,
          state: :all_in,
          current_bet: 300,
          total_contributed: 300,
          has_acted: true,
          current_hand: [%{rank: 12, suit: :spades}, %{rank: 12, suit: :clubs}]
        },
        %PlayerState{
          id: "C",
          remaining_chips: 0,
          state: :all_in,
          current_bet: 300,
          total_contributed: 300,
          has_acted: true,
          current_hand: [%{rank: 3, suit: :spades}, %{rank: 4, suit: :clubs}]
        }
      ]

      community = [
        %{rank: 2, suit: :diamonds},
        %{rank: 7, suit: :clubs},
        %{rank: 5, suit: :diamonds},
        %{rank: 9, suit: :hearts},
        %{rank: 11, suit: :spades}
      ]

      state = %TableState{
        id: "test",
        phase: :showdown,
        players: players,
        pot: 700,
        deck: [],
        community_cards: community,
        small_blind_id: "A",
        current_player_id: "A",
        hands_played: 0
      }

      final = TableState.distribute_pots(state)

      assert TableState.get_player(final, "A").remaining_chips == 300 - 100
      assert TableState.get_player(final, "B").remaining_chips == 400 - 50
      assert TableState.get_player(final, "C").remaining_chips == 0
      assert final.pot == 150
    end
  end

  describe " reset of betting round helpers" do
    test "reset_highest_raise/1 - resets highest_raise to 0", %{state: state} do
      state = Map.put(state, :highest_raise, 500)
      assert TableState.reset_highest_raise(state).highest_raise == 0
    end

    test "reset_current_bet/1 - zeros current_bet for all players", %{state: state} do
      state =
        state
        |> PlayerState.update_current_bet("stine", 100)
        |> PlayerState.update_current_bet("rolf", 200)

      reset = TableState.reset_current_bet(state)
      assert Enum.all?(reset.players, &(&1.current_bet == 0))
    end
  end
end
