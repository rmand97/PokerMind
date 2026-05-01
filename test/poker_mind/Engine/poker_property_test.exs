defmodule PokerMind.Engine.PokerPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PokerMind.Engine.Poker

  @ranks [:A, :K, :Q, :J, :T, 9, 8, 7, 6, 5, 4, 3, 2]
  @suits [:c, :d, :h, :s]
  @all_cards for r <- @ranks, s <- @suits, do: {r, s}

  @valid_categories [
    :straight_flush,
    :four_of_a_kind,
    :full_house,
    :flush,
    :straight,
    :three_of_a_kind,
    :two_pair,
    :one_pair,
    :high_card
  ]

  describe "hand_compare/2 — total-order laws" do
    # Every hand must equal itself. If hand_compare ever returns :gt or :lt
    # for (h, h), the comparator is broken at the most basic level.
    property "reflexivity: hand_compare(h, h) == :eq" do
      check all(hand <- hand_gen()) do
        assert Poker.hand_compare(hand, hand) == :eq
      end
    end

    # Swapping the arguments must invert the result. :gt ↔ :lt, :eq stays :eq.
    # If both directions ever say :gt (or :eq paired with :gt/:lt), the
    # comparator can't be implementing a real ordering.
    property "antisymmetry: hand_compare(b, a) is the inverse of hand_compare(a, b)" do
      check all(a <- hand_gen(), b <- hand_gen()) do
        forward = Poker.hand_compare(a, b)
        reverse = Poker.hand_compare(b, a)

        assert {forward, reverse} in [{:gt, :lt}, {:lt, :gt}, {:eq, :eq}],
               "antisymmetry violated: compare(a,b)=#{inspect(forward)}, " <>
                 "compare(b,a)=#{inspect(reverse)}"
      end
    end

    # Sort a list of hands using hand_compare, then verify every pair (not
    # just adjacent ones) is consistently ordered. If transitivity is
    # violated — a > b > c but a < c — the sorted order will contain at
    # least one non-adjacent pair where the larger appears after the smaller.
    property "transitivity: sorting by hand_compare yields a consistent total order" do
      check all(hands <- list_of(hand_gen(), min_length: 3, max_length: 8)) do
        sorted = Enum.sort(hands, fn a, b -> Poker.hand_compare(a, b) != :lt end)

        for {a, i} <- Enum.with_index(sorted),
            {b, j} <- Enum.with_index(sorted),
            i < j do
          assert Poker.hand_compare(a, b) in [:gt, :eq],
                 "transitivity violated: sorted[#{i}]=#{inspect(a)} should >= " <>
                   "sorted[#{j}]=#{inspect(b)}"
        end
      end
    end

    # The two ways to compare hands must agree. hand_compare is currently
    # implemented in terms of hand_value, so this is a regression guard:
    # if either is rewritten independently, this catches any drift.
    property "hand_compare agrees with the sign of hand_value's difference" do
      check all(a <- hand_gen(), b <- hand_gen()) do
        diff = Poker.hand_value(a) - Poker.hand_value(b)

        expected =
          cond do
            diff > 0 -> :gt
            diff < 0 -> :lt
            true -> :eq
          end

        assert Poker.hand_compare(a, b) == expected
      end
    end
  end

  describe "hand_rank/1 — structural invariants" do
    # hand_rank sorts cards internally via sort_hand, so input order must
    # not affect the result. Catches any future code path that pattern
    # matches on raw input order before sorting.
    property "card-order invariance: any permutation of the 5 cards yields the same rank" do
      check all(hand <- hand_gen()) do
        rank = Poker.hand_rank(hand)
        cards = Tuple.to_list(hand)

        for _ <- 1..5 do
          permuted = cards |> Enum.shuffle() |> List.to_tuple()
          assert Poker.hand_rank(permuted) == rank
        end
      end
    end

    # For non-flush hands, suits don't influence the ranking — only the
    # multiset of ranks does. Applying any bijection on the four suits must
    # preserve the entire rank tuple. For flushes, the category and the
    # five ranks must match; only the suit slot is allowed to change.
    property "suit relabeling preserves hand category (and full rank for non-flush)" do
      check all(hand <- hand_gen(), perm <- member_of(suit_permutations())) do
        rank = Poker.hand_rank(hand)
        relabeled = relabel_suits(hand, perm)
        relabeled_rank = Poker.hand_rank(relabeled)

        assert elem(relabeled_rank, 0) == elem(rank, 0),
               "category changed under suit permutation: #{inspect(rank)} → " <>
                 "#{inspect(relabeled_rank)}"

        if elem(rank, 0) != :flush do
          assert relabeled_rank == rank,
                 "non-flush rank changed under suit permutation: #{inspect(rank)} → " <>
                   "#{inspect(relabeled_rank)}"
        end
      end
    end

    # The wheel (A-2-3-4-5) is the one straight where the ace plays low.
    # A naive high-card check on a sorted hand would call this ace-high.
    # Whatever suits are involved, the rank must be 5-high — straight or
    # straight flush, never anything else.
    property "wheel A-2-3-4-5 is always ranked as 5-high" do
      check all(suits <- list_of(member_of(@suits), length: 5)) do
        cards = [
          {:A, Enum.at(suits, 0)},
          {2, Enum.at(suits, 1)},
          {3, Enum.at(suits, 2)},
          {4, Enum.at(suits, 3)},
          {5, Enum.at(suits, 4)}
        ]

        rank = cards |> List.to_tuple() |> Poker.hand_rank()

        assert rank in [{:straight, 5}, {:straight_flush, 5}],
               "wheel ranked as #{inspect(rank)}"
      end
    end

    # Pull 5 distinct cards from a real 52-card deck and assert hand_rank
    # never crashes and always returns one of the nine known categories.
    # Fuzzes the pattern matches in hand_rank/1 against the full space of
    # legal 5-card subsets.
    property "any 5 distinct cards from a 52-card deck produce a valid category" do
      check all(deck <- shuffled_deck_gen()) do
        hand = deck |> Enum.take(5) |> List.to_tuple()
        rank = Poker.hand_rank(hand)

        assert elem(rank, 0) in @valid_categories,
               "unexpected category #{inspect(elem(rank, 0))} for #{inspect(hand)}"
      end
    end
  end

  describe "best_hand/2 — combinatorial invariants" do
    # The 5 cards in the returned hand must come from (hole ++ community).
    # best_hand can't invent, duplicate, or substitute cards. A bug in the
    # comb/2 + sort_by + List.to_tuple pipeline could return a malformed
    # subset alongside the correct rank.
    property "best_hand returns a 5-card subset of (hole ++ community)" do
      check all(deck <- shuffled_deck_gen()) do
        hole = deck |> Enum.take(2) |> List.to_tuple()
        community = deck |> Enum.slice(2, 5) |> List.to_tuple()

        {_rank, hand} = Poker.best_hand(hole, community)

        chosen = Tuple.to_list(hand)
        available = Tuple.to_list(hole) ++ Tuple.to_list(community)

        assert length(chosen) == 5
        assert length(Enum.uniq(chosen)) == 5

        assert Enum.all?(chosen, &(&1 in available)),
               "best_hand returned cards not in input: #{inspect(chosen -- available)}"
      end
    end

    # Compute hand_value over all C(7,5)=21 five-card subsets of the
    # 7 available cards and verify best_hand picked the maximum. This is
    # the most direct test of the search logic in best_hand/2.
    property "best_hand value equals the maximum over all 5-card subsets" do
      # O(n^5) over 52 cards
      check all(deck <- shuffled_deck_gen(), max_runs: 200) do
        cards = Enum.take(deck, 7)
        hole = cards |> Enum.take(2) |> List.to_tuple()
        community = cards |> Enum.slice(2, 5) |> List.to_tuple()

        {_rank, best} = Poker.best_hand(hole, community)
        best_val = Poker.hand_value(best)

        max_val =
          cards
          |> combinations(5)
          |> Enum.map(fn five -> Poker.hand_value(List.to_tuple(five)) end)
          |> Enum.max()

        assert best_val == max_val,
               "best_hand picked value #{best_val}, but max over subsets is #{max_val}"
      end
    end

    # As streets are revealed, the player's best 5-card hand is chosen from
    # a strictly larger pool: 5 cards on the flop, 6 on the turn, 7 on the
    # river. More candidates can never make the chosen hand worse, so the
    # value must be non-decreasing flop → turn → river.
    property "best_hand value is non-decreasing flop → turn → river" do
      check all(deck <- shuffled_deck_gen()) do
        hole = deck |> Enum.take(2) |> List.to_tuple()
        flop = Enum.slice(deck, 2, 3)
        turn = Enum.at(deck, 5)
        river = Enum.at(deck, 6)

        flop_board = List.to_tuple(flop)
        turn_board = List.to_tuple(flop ++ [turn])
        river_board = List.to_tuple(flop ++ [turn, river])

        {_, flop_hand} = Poker.best_hand(hole, flop_board)
        {_, turn_hand} = Poker.best_hand(hole, turn_board)
        {_, river_hand} = Poker.best_hand(hole, river_board)

        flop_val = Poker.hand_value(flop_hand)
        turn_val = Poker.hand_value(turn_hand)
        river_val = Poker.hand_value(river_hand)

        assert flop_val <= turn_val,
               "best_hand value dropped flop→turn: #{flop_val} → #{turn_val}"

        assert turn_val <= river_val,
               "best_hand value dropped turn→river: #{turn_val} → #{river_val}"
      end
    end
  end

  # Generators & helpers

  # Yields a uniformly random 5-card hand drawn from a 52-card deck.
  # Driving randomness via stream_data weights (rather than Enum.shuffle)
  # keeps generation reproducible from the property's seed.
  defp hand_gen do
    gen all(weights <- list_of(integer(), length: 52)) do
      @all_cards
      |> Enum.zip(weights)
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.take(5)
      |> Enum.map(&elem(&1, 0))
      |> List.to_tuple()
    end
  end

  # Yields a uniformly random permutation of the full 52-card deck.
  defp shuffled_deck_gen do
    gen all(weights <- list_of(integer(), length: 52)) do
      @all_cards
      |> Enum.zip(weights)
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    end
  end

  defp suit_permutations do
    for [a, b, c, d] <- permutations(@suits) do
      %{c: a, d: b, h: c, s: d}
    end
  end

  defp permutations([]), do: [[]]

  defp permutations(list) do
    for x <- list, rest <- permutations(list -- [x]), do: [x | rest]
  end

  defp relabel_suits(hand, perm) do
    hand
    |> Tuple.to_list()
    |> Enum.map(fn {rank, suit} -> {rank, perm[suit]} end)
    |> List.to_tuple()
  end

  defp combinations(_, 0), do: [[]]
  defp combinations([], _), do: []

  defp combinations([h | t], n) do
    for(rest <- combinations(t, n - 1), do: [h | rest]) ++ combinations(t, n)
  end
end
