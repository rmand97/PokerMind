defmodule PokerMind.Engine.TableState do
  alias PokerMind.Engine.Poker
  alias PokerMind.Engine.TableState.PlayerState

  @enforce_keys [:id, :phase, :players, :pot, :deck, :community_cards]
  defstruct [
    # table-id
    :id,
    # :pre_flop | :flop | :turn | :river | :showdown
    :phase,
    # list of %TableState.PlayerState{} structs
    :players,
    # current pot
    :pot,
    # remaining cards
    :deck,
    # cards on the table
    :community_cards,
    # Player who is small blind
    :small_blind_id,
    # whose turn
    :current_player_id,
    # bet to match
    :highest_raise,
    :big_blind_amount,
    :winner
  ]

  def new(id) when is_binary(id) do
    # when we initialize a new table, highest_raise and big_blind_amount is the same
    %__MODULE__{
      id: id,
      phase: :pre_flop,
      players: [],
      pot: 0,
      deck: [],
      community_cards: []
    }
  end

  def init(%__MODULE__{} = state, init_players) when is_list(init_players) do
    state
    |> initialize_players(init_players)
    |> new_deck()
    |> set_blinds()
    |> deal_cards()
  end

  defp initialize_players(%__MODULE__{} = state, []) do
    state
  end

  defp initialize_players(%__MODULE__{} = state, [first_player | rest]) do
    initialize_players(add_player(state, first_player), rest)
  end

  defp add_player(%__MODULE__{} = state, new_player_id)
       when is_binary(new_player_id)
       when is_list(state.players) do
    new_player = PlayerState.new(new_player_id, 1000)

    Map.put(state, :players, [new_player | state.players])
  end

  def set_player_value(%__MODULE__{} = state, player_id, key, new_key_value) do
    updated_players =
      Enum.map(state.players, fn player ->
        if player.id == player_id do
          PlayerState.set_player_value(player, key, new_key_value)
        else
          player
        end
      end)

    %__MODULE__{state | players: updated_players}
  end

  # TODO: update with setting blinds and deducting chips from players
  defp set_blinds(%__MODULE__{} = state, new_table \\ true) when is_boolean(new_table) do
    new_state =
      if new_table do
        small_blind_id = Enum.random(state.players).id
        Map.put(state, :small_blind_id, small_blind_id)
      else
        advance_player(state, :small_blind_id, state.small_blind_id)
      end

    big_blind = 100

    new_state
    |> Map.put(:highest_raise, big_blind)
    |> Map.put(:big_blind_amount, big_blind)
    |> advance_player(:current_player_id, new_state.small_blind_id)
    |> advance_player()
  end

  # TODO validation function på player_state skal være en af følgende
  # :active_in_hand | :inactive_in_hand | :out_of_chips | :all_in

  def advance_player(%__MODULE__{} = state, key \\ :current_player_id, player_id \\ nil)
      when is_nil(player_id) or is_binary(player_id) do
    from_player_id =
      case player_id do
        nil -> state.current_player_id
        player_id -> player_id
      end

    index = Enum.find_index(state.players, fn p -> p.id == from_player_id end)
    next_player = Enum.at(state.players, rem(index + 1, length(state.players)))

    state
    |> Map.put(key, next_player.id)
  end

  defp new_deck(%__MODULE__{} = state) do
    suits = [:hearts, :diamonds, :clubs, :spades]
    ranks = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

    deck =
      for suit <- suits, rank <- ranks do
        %{rank: rank, suit: suit}
      end
      |> Enum.shuffle()

    state
    |> Map.put(:deck, deck)
  end

  def deal_cards(%__MODULE__{} = state) do
    {updated_players, remaining_deck} =
      Enum.map_reduce(state.players, state.deck, fn %PlayerState{} = player, acc ->
        if player.state == :active_in_hand do
          {drawn, remaining} = Enum.split(acc, 2)
          {%{player | current_hand: drawn}, remaining}
        else
          {player, acc}
        end
      end)

    state
    |> Map.put(:deck, remaining_deck)
    |> Map.put(:players, updated_players)
  end

  @valid_transitions %{
    :pre_flop => [:flop, :showdown],
    :flop => [:turn, :showdown],
    :turn => [:river, :showdown],
    :river => [:showdown],
    :showdown => [:hand_finished]
  }

  def next_phase(%__MODULE__{} = state) do
    active_count = Enum.count(state.players, fn player -> player.state == :active_in_hand end)

    if active_count <= 1 and state.phase != :showdown do
      :showdown
    else
      case state.phase do
        :pre_flop -> :flop
        :flop -> :turn
        :turn -> :river
        :river -> :showdown
        :showdown -> :hand_finished
      end
    end
  end

  defp deal_community_cards(%__MODULE__{} = state, amount) when is_integer(amount) do
    {drawn, remaining} = Enum.split(state.deck, amount)

    state
    |> Map.update(:community_cards, drawn, fn existing -> existing ++ drawn end)
    |> Map.put(:deck, remaining)
  end

  def advance_phase(%__MODULE__{} = state, next_phase) when is_atom(next_phase) do
    if next_phase in Map.get(@valid_transitions, state.phase, []) do
      new_state = Map.put(state, :phase, next_phase)

      case next_phase do
        :flop -> deal_community_cards(new_state, 3)
        :turn -> deal_community_cards(new_state, 1)
        :river -> deal_community_cards(new_state, 1)
        :showdown -> handle_showdown(new_state)
        :hand_finished -> possible_new_hand(new_state)
      end
    else
      {:error, {:invalid_transition, state.phase, next_phase}}
    end
  end

  def set_current_player_for_phase(%__MODULE__{} = state) do
    start_from_id =
      case state.phase do
        # if pre_flop bb+1 goes first. if he is inactive -> pick next active
        :pre_flop ->
          after_small_blind_id = find_next_active_player(state, state.small_blind_id)
          after_big_blind_id = find_next_active_player(state, after_small_blind_id)
          after_big_blind_id

        _post_flop ->
          # in any other case/phase sb goes first. if he is inactive -> pick next active
          state.small_blind_id
      end

    start_from_player = get_player(state, start_from_id)

    # check if inactive pick next active
    start_from_player =
      if start_from_player.state == :active_in_hand do
        start_from_player
        # if inactive pick next active
      else
        find_next_active_player(state, start_from_player)
      end

    %{state | current_player_id: start_from_player.id}
  end

  def round_complete?(%__MODULE__{players: players}) do
    active_players =
      Enum.filter(players, fn player ->
        player.state == :active_in_hand
      end)

    Enum.all?(active_players, fn player ->
      player.has_acted
    end)
  end

  def find_next_active_player(%__MODULE__{players: players}, from_player_id)
      when is_binary(from_player_id) do
    players_to_consider = acting_order_from(players, from_player_id)

    players_to_consider
    |> Enum.find(fn player -> player.state == :active_in_hand end)
  end

  defp acting_order_from(players, from_player_id) when is_binary(from_player_id) do
    # Where is from_player in list
    start = Enum.find_index(players, fn player -> player.id == from_player_id end)

    # Split list and remove from_player
    {first_list, [_from_player | second_list]} = Enum.split(players, start)

    # order rest of players in turn order
    second_list ++ first_list
  end

  def complete_current_player_turn(%__MODULE__{} = state) do
    update_in(
      state,
      [
        Access.key(:players),
        Access.find(fn player -> player.id == state.current_player_id end),
        Access.key(:has_acted)
      ],
      fn _current_value -> true end
    )
  end

  def get_player(%__MODULE__{} = state, player_id) when is_binary(player_id) do
    Enum.find(state.players, &(&1.id == player_id))
  end

  def add_to_pot(%__MODULE__{} = state, player_id, amount)
      when is_integer(amount) and amount > 0 do
    amount_difference = amount - get_player(state, player_id).current_bet

    state
    |> PlayerState.deduct_chips(player_id, amount_difference)
    |> PlayerState.update_current_bet(player_id, amount)
    |> Map.put(:pot, state.pot + amount_difference)
  end

  def update_highest_raise(%__MODULE__{} = state, amount)
      when is_integer(amount) and amount > 0 do
    Map.put(state, :highest_raise, amount)
  end

  def compare_cards(rank1, rank2)
      when is_integer(rank1) and is_integer(rank2) do
    rank1 = normalize_rank(rank1)
    rank2 = normalize_rank(rank2)

    cond do
      rank1 < rank2 -> :lt
      rank1 > rank2 -> :gt
      true -> :eq
    end
  end

  defp normalize_rank(1) do
    14
  end

  defp normalize_rank(rank) when is_integer(rank) and rank > 1 and rank < 14 do
    rank
  end

  defp rank_to_string(rank) when is_integer(rank) do
    case rank do
      1 -> "A"
      10 -> "T"
      11 -> "J"
      12 -> "Q"
      13 -> "K"
      n when n >= 2 and n <= 9 -> Integer.to_string(n)
    end
  end

  defp suit_to_string(suit) when is_atom(suit) do
    case suit do
      :hearts -> "h"
      :diamonds -> "d"
      :clubs -> "c"
      :spades -> "s"
    end
  end

  defp translate_card(%{rank: rank, suit: suit}) do
    "#{rank_to_string(rank)}#{suit_to_string(suit)}"
  end

  defp translate_cards(cards) do
    Enum.map_join(cards, " ", fn card -> translate_card(card) end)
  end

  def compare_hands(hand1, hand2, community_cards) do
    # Change format for cards to match the args for best_hand/2
    translated_hand1 = translate_cards(hand1)
    translated_hand2 = translate_cards(hand2)
    translated_community_cards = translate_cards(community_cards)

    {_, best_hand1} = Poker.best_hand(translated_hand1, translated_community_cards)
    {_, best_hand2} = Poker.best_hand(translated_hand2, translated_community_cards)

    Poker.hand_compare(best_hand1, best_hand2)
  end

  # TODO handle sidepot
  def split_pot(%__MODULE__{} = state, winners) when is_list(winners) do
    leftover_chips = rem(state.pot, length(winners))
    winning_chips = div(state.pot - leftover_chips, length(winners))

    # Distribute leftover chips one for each winner, starting with the first winning player
    new_state =
      if leftover_chips > 0 do
        Enum.reduce(0..(leftover_chips - 1), state, fn i, current_state ->
          winner_id = Enum.at(winners, i)
          PlayerState.add_chips(current_state, winner_id, 1)
        end)
      else
        state
      end

    # Distribute winnings to all winners
    final_state =
      Enum.reduce(winners, new_state, fn winner_id, current_state ->
        PlayerState.add_chips(current_state, winner_id, winning_chips)
      end)

    Map.put(final_state, :pot, 0)
  end

  defp accumulate_winner(player, {_winners, nil}, _community_cards) do
    {[player], player}
  end

  defp accumulate_winner(player, {winners, best}, community_cards) do
    case compare_hands(player.current_hand, best.current_hand, community_cards) do
      :gt -> {[player], player}
      :lt -> {winners, best}
      :eq -> {[player | winners], best}
    end
  end

  defp find_winners(players, community_cards) do
    {winners, _} =
      Enum.reduce(players, {[], nil}, fn player, acc ->
        accumulate_winner(player, acc, community_cards)
      end)

    Enum.map(winners, fn winner -> winner.id end)
  end

  # TODO handle sidepots
  defp handle_showdown(%__MODULE__{} = state) do
    active_players =
      Enum.filter(state.players, fn player -> player.state in [:active_in_hand, :all_in] end)

    case active_players do
      [winner] ->
        split_pot(state, [winner.id])

      players ->
        new_state =
          if length(state.community_cards) < 5 do
            deal_community_cards(state, 5 - length(state.community_cards))
          else
            state
          end

        winner_ids = find_winners(players, new_state.community_cards)
        split_pot(new_state, winner_ids)
    end
  end

  defp possible_new_hand(%__MODULE__{} = state) do
    players_with_remaining_chips =
      Enum.filter(state.players, fn player -> player.remaining_chips > 0 end)

    if length(players_with_remaining_chips) == 1 do
      [winner] = players_with_remaining_chips

      state
      |> Map.put(:winner, winner.id)
      |> Map.put(:phase, :game_finished)
    else
      new_state =
        Enum.reduce(state.players, state, fn player, current_state ->
          current_state
          |> set_player_value(player.id, :current_hand, [])
          |> set_player_value(player.id, :current_bet, 0)
          |> set_player_value(player.id, :has_acted, false)
          |> reset_player_state(player)
        end)

      new_state
      |> Map.put(:community_cards, [])
      |> new_deck()
      |> set_blinds(false)
      |> deal_cards()
      |> Map.put(:phase, :pre_flop)
    end
  end

  defp reset_player_state(state, player) do
    new_state =
      if player.remaining_chips == 0,
        do: :out_of_chips,
        else: :active_in_hand

    set_player_value(state, player.id, :state, new_state)
  end
end
