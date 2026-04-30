defmodule PokerMind.Engine.IntegrationTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.Actions

  describe "Game 1 - Re-raises (2 players)" do
    test "play 3 hands and verify final outcome" do
      id = UUID.uuid4()
      state = TableState.init(TableState.new(id), ["stine", "rolf"])

      # sets player 1 to small_blind
      {player1_id, player2_id} = get_players(state)

      community_cards_hand_1 = [
        {11, :hearts},
        {4, :diamonds},
        {2, :clubs},
        {13, :spades},
        {7, :diamonds}
      ]

      community_cards_hand_2 = [
        {10, :clubs},
        {8, :clubs},
        {3, :clubs},
        {2, :spades},
        {6, :diamonds}
      ]

      community_cards_hand_3 = [
        {13, :hearts},
        {12, :diamonds},
        {5, :clubs},
        {3, :spades},
        {9, :diamonds}
      ]

      gameplay =
        state
        # Hand 1
        |> set_player_hand(player1_id, [{11, :spades}, {11, :diamonds}])
        |> set_player_hand(player2_id, [{9, :clubs}, {8, :clubs}])
        |> raise_(player1_id, 300)
        |> call(player2_id, 300)
        |> raise_(player1_id, 400)
        |> call(player2_id, 400)
        |> raise_(player1_id, 600)
        |> call(player2_id, 600)
        |> set_community_cards(community_cards_hand_1)
        |> check(player1_id)
        |> check(player2_id)
        # Hand 2
        |> set_player_hand(player1_id, [{1, :diamonds}, {12, :diamonds}])
        |> set_player_hand(player2_id, [{13, :clubs}, {9, :clubs}])
        |> raise_(player2_id, 500)
        |> raise_(player1_id, 1_500)
        |> call(player2_id, 1_500)
        |> set_community_cards(community_cards_hand_2)
        |> check(player2_id)
        |> raise_(player1_id, 2_000)
        |> all_in(player2_id)
        |> call(player1_id, 7200)
        # Hand 3
        |> set_player_hand(player1_id, [{1, :spades}, {7, :hearts}])
        |> set_player_hand(player2_id, [{13, :diamonds}, {12, :clubs}])
        |> set_community_cards(community_cards_hand_3)
        |> raise_(player1_id, 500)
        |> raise_(player2_id, 1_500)
        |> all_in(player1_id)
        |> call(player2_id, 2_600)

      # Game has ended, P2 wins
      assert gameplay.phase == :game_finished
      assert gameplay.winner == player2_id
    end
  end

  describe "Game 2 - Instant Victory (2 players)" do
    test "instant victory - player 1 wins in a single hand" do
      id = UUID.uuid4()
      state = TableState.init(TableState.new(id), ["stine", "rolf"])

      # sets player 1 to small_blind
      {player1_id, player2_id} = get_players(state)

      community_cards = [
        {1, :hearts},
        {7, :clubs},
        {2, :hearts},
        {11, :spades},
        {9, :clubs}
      ]

      gameplay =
        state
        # Hand 1
        |> set_player_hand(player1_id, [{1, :clubs}, {1, :spades}])
        |> set_player_hand(player2_id, [{13, :diamonds}, {12, :spades}])
        |> set_community_cards(community_cards)
        |> all_in(player1_id)
        |> all_in(player2_id)

      # Game has ended, P1 wins
      assert gameplay.phase == :game_finished
      assert gameplay.winner == player1_id
    end
  end

  describe "Game 3 - Ends in Level 1 (3 players)" do
    test "play 6 hands and verify final outcome" do
      id = UUID.uuid4()
      state = TableState.init(TableState.new(id), ["stine", "rolf", "asbjørn"])

      # sets player 2 to small_blind and player_1 to current_player
      {player2_id, player3_id, player1_id} = get_players(state)

      community_cards_hand_1 = [
        {10, :spades},
        {9, :spades},
        {3, :diamonds},
        {8, :diamonds},
        {2, :clubs}
      ]

      community_cards_hand_2 = [
        {1, :diamonds},
        {5, :clubs},
        {2, :spades},
        {11, :clubs},
        {9, :spades}
      ]

      community_cards_hand_3 = [
        {5, :diamonds},
        {13, :clubs},
        {2, :hearts},
        {11, :spades},
        {7, :diamonds}
      ]

      community_cards_hand_4 = [
        {12, :spades},
        {10, :diamonds},
        {9, :clubs},
        {8, :spades},
        {2, :diamonds}
      ]

      community_cards_hand_5 = [
        {8, :spades},
        {8, :clubs},
        {3, :diamonds},
        {12, :hearts},
        {5, :spades}
      ]

      community_cards_hand_6 = [
        {13, :spades},
        {9, :diamonds},
        {4, :clubs},
        {3, :spades},
        {6, :diamonds}
      ]

      gameplay =
        state
        # Hand 1: P2 wins with straight
        |> set_player_hand(player1_id, [{5, :diamonds}, {4, :diamonds}])
        |> set_player_hand(player2_id, [{12, :spades}, {11, :spades}])
        |> set_player_hand(player3_id, [{1, :clubs}, {6, :hearts}])
        |> fold(player1_id)
        |> raise_(player2_id, 300)
        |> call(player3_id, 300)
        |> raise_(player2_id, 400)
        |> call(player3_id, 400)
        |> raise_(player2_id, 800)
        |> call(player3_id, 800)
        |> set_community_cards(community_cards_hand_1)
        |> raise_(player2_id, 1_500)
        |> call(player3_id, 1_500)
        # Hand 2: P1 wins with pair of Aces
        |> set_player_hand(player1_id, [{1, :hearts}, {13, :clubs}])
        |> set_player_hand(player2_id, [{13, :hearts}, {3, :diamonds}])
        |> set_player_hand(player3_id, [{7, :clubs}, {6, :spades}])
        |> fold(player2_id)
        |> raise_(player3_id, 400)
        |> raise_(player1_id, 1_200)
        |> call(player3_id, 1_200)
        |> check(player3_id)
        |> raise_(player1_id, 1_500)
        |> call(player3_id, 1_500)
        |> check(player3_id)
        |> raise_(player1_id, 3_600)
        |> call(player3_id, 3_600)
        |> set_community_cards(community_cards_hand_2)
        |> check(player3_id)
        |> check(player1_id)
        # Hand 3: P3 wins with trip Fives
        |> set_player_hand(player1_id, [{12, :diamonds}, {8, :spades}])
        |> set_player_hand(player2_id, [{9, :spades}, {4, :clubs}])
        |> set_player_hand(player3_id, [{5, :hearts}, {5, :clubs}])
        |> set_community_cards(community_cards_hand_3)
        |> all_in(player3_id)
        |> call(player1_id, 700)
        |> fold(player2_id)
        # Hand 4: P2 wins with straight, P3 eliminated
        |> set_player_hand(player1_id, [{10, :hearts}, {8, :diamonds}])
        |> set_player_hand(player2_id, [{1, :spades}, {11, :diamonds}])
        |> set_player_hand(player3_id, [{13, :clubs}, {6, :hearts}])
        |> set_community_cards(community_cards_hand_4)
        |> fold(player1_id)
        |> raise_(player2_id, 400)
        |> all_in(player3_id)
        |> call(player2_id, 1_500)
        # Hand 5: P1 wins with quad Eights
        |> set_player_hand(player1_id, [{8, :hearts}, {8, :diamonds}])
        |> set_player_hand(player2_id, [{1, :clubs}, {13, :spades}])
        |> call(player1_id, 100)
        |> raise_(player2_id, 500)
        |> raise_(player1_id, 1_500)
        |> call(player2_id, 1_500)
        |> raise_(player1_id, 2_000)
        |> raise_(player2_id, 5_000)
        |> raise_(player1_id, 12_850)
        |> call(player2_id, 12_850)
        |> check(player1_id)
        |> check(player2_id)
        |> set_community_cards(community_cards_hand_5)
        |> check(player1_id)
        |> check(player2_id)
        # Hand 6: P1 wins with pair of Kings, P2 eliminated
        |> set_player_hand(player1_id, [{13, :diamonds}, {7, :spades}])
        |> set_player_hand(player2_id, [{11, :clubs}, {2, :hearts}])
        |> set_community_cards(community_cards_hand_6)
        |> check(player1_id)

      # Game has ended, P1 wins
      assert gameplay.phase == :game_finished
      assert gameplay.winner == player1_id
    end
  end

  defp raise_(state, player_id, amount) do
    Actions.apply_action(state, %{type: :raise, player_id: player_id, amount: amount})
  end

  defp call(state, player_id, amount) do
    Actions.apply_action(state, %{type: :call, player_id: player_id, amount: amount})
  end

  defp check(state, player_id) do
    Actions.apply_action(state, %{type: :check, player_id: player_id})
  end

  defp fold(state, player_id) do
    Actions.apply_action(state, %{type: :fold, player_id: player_id})
  end

  defp all_in(state, player_id) do
    Actions.apply_action(state, %{type: :all_in, player_id: player_id})
  end

  defp withdraw_cards_from_deck(state, cards) do
    Map.update!(state, :deck, fn deck ->
      Enum.reject(deck, fn card ->
        Enum.any?(cards, fn {rank, suit} ->
          card.rank == rank and card.suit == suit
        end)
      end)
    end)
  end

  defp set_player_hand(state, player_id, cards)
       when is_binary(player_id) and is_list(cards) do
    player = TableState.get_player(state, player_id)
    current_cards = player.current_hand

    state
    |> Map.put(:deck, state.deck ++ current_cards)
    |> withdraw_cards_from_deck(cards)
    |> then(fn state ->
      mapped_cards = Enum.map(cards, fn {rank, suit} -> %{rank: rank, suit: suit} end)
      TableState.set_player_value(state, player_id, :current_hand, mapped_cards)
    end)
  end

  defp set_community_cards(state, cards)
       when is_list(cards) do
    current_cards = state.community_cards

    state
    |> Map.put(:deck, state.deck ++ current_cards)
    |> withdraw_cards_from_deck(cards)
    |> then(fn state ->
      mapped_cards = Enum.map(cards, fn {rank, suit} -> %{rank: rank, suit: suit} end)
      Map.put(state, :community_cards, mapped_cards)
    end)
  end

  defp get_players(state) do
    small_blind_index =
      Enum.find_index(state.players, fn player -> player.id == state.small_blind_id end)

    count = length(state.players)

    players =
      for player_index <- 0..(count - 1) do
        Enum.at(state.players, rem(small_blind_index + player_index, count)).id
      end

    List.to_tuple(players)
  end
end
