defmodule PokerMind.Engine.TableStatePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

  describe "deal_cards/1 (property-based)" do
    property "every deal yields a 52-card deck partition: 2 cards per active player, inactive untouched, no duplicates" do
      check all players <- players_generator() do
        state = %TableState{
          id: "test-table",
          phase: :pre_flop,
          players: players,
          pot: 0,
          deck: shuffled_deck(),
          community_cards: []
        }

        new_state = TableState.deal_cards(state)

        {active, inactive} =
          Enum.split_with(new_state.players, &(&1.state == :active_in_hand))

        # 1. Every active player gets exactly 2 cards.
        for player <- active do
          assert length(player.current_hand) == 2,
                 "active player #{player.id} should have 2 cards, got #{inspect(player.current_hand)}"
        end

        # 2. Inactive players are untouched (hand stays nil).
        for player <- inactive do
          assert player.current_hand == nil
        end

        # 3. Remaining deck shrinks by exactly 2 per active player.
        assert length(new_state.deck) == 52 - 2 * length(active)

        # 4. Deck + dealt hands together form the full 52-card set with no duplicates.
        dealt = Enum.flat_map(active, & &1.current_hand)
        all_cards = new_state.deck ++ dealt

        assert length(all_cards) == 52
        assert length(Enum.uniq(all_cards)) == 52
      end
    end
  end

  # Generates 2–10 players with independently-chosen states, so each run
  # exercises a different mix of active and inactive seats (including the
  # all-inactive and all-active corners).
  defp players_generator do
    gen all count <- integer(2..10),
            states <-
              list_of(member_of([:active_in_hand, :inactive_in_hand]), length: count) do
      states
      |> Enum.with_index()
      |> Enum.map(fn {state, idx} ->
        %PlayerState{
          id: "player_#{idx}",
          remaining_chips: 1000,
          state: state,
          current_bet: 0,
          has_acted: false
        }
      end)
    end
  end

  defp shuffled_deck do
    for suit <- [:hearts, :diamonds, :clubs, :spades], rank <- 1..13 do
      %{rank: rank, suit: suit}
    end
    |> Enum.shuffle()
  end
end
