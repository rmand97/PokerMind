defmodule PokerMind.Engine.TableStatePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PokerMind.Engine.Actions
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

  describe "Actions.apply_action/2 (property-based)" do
    # Core invariant of any poker engine: chips are conserved.
    # No matter what sequence of actions is applied — legal, illegal, mid-hand,
    # post-showdown, across new-hand resets — the total number of chips on the
    # table (pot + every player's stack) must never change.
    #
    # This one property exercises:
    #   * all apply_action branches (fold, check, call, raise, all_in, invalid)
    #   * add_to_pot's `amount - current_bet` delta math
    #   * all_in's `chips + bet` computation
    #   * split_pot on showdown (including leftover-chip distribution)
    #   * possible_new_hand's reset + deal pipeline
    #   * validation short-circuits (errors must leave state untouched)
    property "total chips (stacks + pot) are conserved across any action sequence" do
      check all(
              actions <- list_of(action_gen(), min_length: 1, max_length: 40),
              max_runs: 200
            ) do
        init_state =
          TableState.init(TableState.new("table"), ["alice", "bob", "carol"])

        initial_total = total_chips(init_state)

        final_state =
          Enum.reduce(actions, init_state, fn action, state ->
            # apply_action returns either a new %TableState{} or {:error, _}.
            # Errors must leave chip totals untouched — which is exactly what
            # the reduce expresses by keeping `state` unchanged on error.
            full_action = Map.put(action, :player_id, state.current_player_id)

            case Actions.apply_action(state, full_action) do
              %TableState{} = new_state ->
                assert total_chips(new_state) == initial_total,
                       "chips not conserved after #{inspect(full_action)}: " <>
                         "expected #{initial_total}, got #{total_chips(new_state)}"

                new_state

              {:error, _} ->
                state
            end
          end)

        assert total_chips(final_state) == initial_total
      end
    end
  end

  describe "deal_cards/1 (property-based)" do
    property "every deal yields a 52-card deck partition: 2 cards per active player, inactive untouched, no duplicates" do
      check all(players <- players_generator()) do
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

        for player <- active do
          assert length(player.current_hand) == 2,
                 "active player #{player.id} should have 2 cards, got #{inspect(player.current_hand)}"
        end

        for player <- inactive do
          assert player.current_hand == nil
        end

        assert length(new_state.deck) == 52 - 2 * length(active)

        dealt = Enum.flat_map(active, & &1.current_hand)
        all_cards = new_state.deck ++ dealt

        assert length(all_cards) == 52
        assert length(Enum.uniq(all_cards)) == 52
      end
    end
  end

  defp players_generator do
    gen all(
          count <- integer(2..10),
          states <-
            list_of(member_of([:active_in_hand, :inactive_in_hand]), length: count)
        ) do
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

  defp total_chips(%TableState{} = state) do
    state.pot + Enum.sum(Enum.map(state.players, & &1.remaining_chips))
  end

  # Yields random action intents (player_id is injected later, based on whose
  # turn it is in the current state). Amounts are biased toward the 100–800
  # range so a non-trivial fraction of raises/calls actually validate, exposing
  # more of the engine; the occasional out-of-range value still exercises the
  # validation short-circuit paths.
  defp action_gen do
    one_of([
      constant(%{type: :fold}),
      constant(%{type: :check}),
      constant(%{type: :all_in}),
      constant(%{type: :garbage_action_not_supported}),
      amount_action_gen(:call),
      amount_action_gen(:raise)
    ])
  end

  defp amount_action_gen(type) do
    gen all(amount <- integer(1..1200)) do
      %{type: type, amount: amount}
    end
  end

  defp shuffled_deck do
    for suit <- [:hearts, :diamonds, :clubs, :spades], rank <- 1..13 do
      %{rank: rank, suit: suit}
    end
    |> Enum.shuffle()
  end
end
