defmodule PokerMind.Engine.IntegrationTest do
  use ExUnit.Case, async: true
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.Actions

  describe "Game 1 (2 players)" do
    test "play 3 hands and verify final outcome" do
      id = UUID.uuid4()
      state = TableState.init(TableState.new(id), ["stine", "rolf"])

      # set player 1 to small_blind
      player1_id = state.small_blind_id
      player2_id = Enum.find(state.players, fn player -> player.id != player1_id end).id

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

  defp raise_(state, player_id, amount) do
    Actions.apply_action(state, %{type: :raise, player_id: player_id, amount: amount})
  end

  defp call(state, player_id, amount) do
    Actions.apply_action(state, %{type: :call, player_id: player_id, amount: amount})
  end

  defp check(state, player_id) do
    Actions.apply_action(state, %{type: :check, player_id: player_id})
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
end
