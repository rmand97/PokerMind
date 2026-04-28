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
    :winner,
    :hands_played
  ]

  def new(id) when is_binary(id) do
    # when we initialize a new table, highest_raise and big_blind_amount is the same
    %__MODULE__{
      id: id,
      phase: :pre_flop,
      players: [],
      pot: 0,
      deck: [],
      community_cards: [],
      hands_played: 0
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
    new_player = PlayerState.new(new_player_id, 10_000)

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

  defp set_blinds(%__MODULE__{} = state, new_table \\ true) when is_boolean(new_table) do
    new_state =
      if new_table do
        small_blind_id = Enum.random(state.players).id
        Map.put(state, :small_blind_id, small_blind_id)
      else
        advance_player(state, :small_blind_id, state.small_blind_id)
      end

    base_blind = 100
    increase_every = 10
    big_blind = base_blind * 2 ** div(state.hands_played, increase_every)

    new_state
    |> Map.put(:highest_raise, big_blind)
    |> Map.put(:big_blind_amount, big_blind)
    |> add_to_pot(new_state.small_blind_id, div(big_blind, 2))
    |> advance_player(:current_player_id, new_state.small_blind_id)
    |> then(fn state ->
      big_blind_id = state.current_player_id
      add_to_pot(state, big_blind_id, big_blind)
    end)
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
        find_next_active_player(state, start_from_player.id)
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
    player_contribution = get_player(state, player_id).total_contributed

    state
    |> set_player_value(
      player_id,
      :total_contributed,
      player_contribution + amount_difference
    )
    |> PlayerState.deduct_chips(player_id, amount_difference)
    |> PlayerState.update_current_bet(player_id, amount)
    |> Map.put(:pot, state.pot + amount_difference)
  end

  @doc """
  Derives the pot structure at showdown from players' total contributions.

  Returns `%{pots: [%{amount, eligible_ids}], refunds: [{player_id, amount}]}`.

  - Each pot layer is capped at a distinct contribution level from players
    still in the hand (active or all-in).
  - A folded player's chips flow into the layers their contribution covers,
    but they're never eligible to win any pot.
  - A layer with only one eligible player (uncontested) is returned to that
    player as a refund rather than paid out as a pot.
  """
  def build_pots(%__MODULE__{players: players}) do
    players_still_in_hand = Enum.filter(players, &(&1.state in [:active_in_hand, :all_in]))

    # Get distinct contribution layers among players still in hand, sorted ascending.
    # These will be the caps of each pot layer, starting from the smallest. For example, if
    # three players contributed 100, 200, and 500 chips, there will be three layers capped at
    # 100, 200, and 500 chips respectively.
    # The first layer includes all players, the second layer includes the two biggest contributors,
    # and the third layer includes only the biggest contributor
    # uniq is important because multiple players can have the same contribution, but that only creates one level/layer
    layers =
      players_still_in_hand
      |> Enum.map(& &1.total_contributed)
      |> Enum.uniq()
      |> Enum.sort()

    {raw_pots, _} =
      Enum.map_reduce(layers, 0, fn layer, prev_layer ->
        amount =
          Enum.reduce(players, 0, fn p, sum ->
            sum + max(0, min(p.total_contributed, layer) - prev_layer)
          end)

        eligible_player_ids =
          players_still_in_hand
          |> Enum.filter(&(&1.total_contributed >= layer))
          |> Enum.map(& &1.id)

        {%{amount: amount, eligible_ids: eligible_player_ids}, layer}
      end)

    # Collapse single-eligible pots into refunds (uncontested middle/top layers).
    {pots, refunds} =
      Enum.reduce(raw_pots, {[], []}, fn
        # If no chips in this layer, skip it
        %{amount: 0}, acc ->
          acc

        # If only one eligible player, this layer is an uncontested pot and should be refunded, not paid out
        %{eligible_ids: [only_player]} = pot, {pots_acc, refunds_acc} ->
          {pots_acc, [{only_player, pot.amount} | refunds_acc]}

        # Otherwise, this is a contested pot layer that should be paid out to the eligible players
        pot, {pots_acc, refunds_acc} ->
          {[pot | pots_acc], refunds_acc}
      end)

    %{
      pots: Enum.reverse(pots),
      refunds: Enum.reverse(refunds)
    }
  end

  def update_highest_raise(%__MODULE__{} = state, amount)
      when is_integer(amount) and amount > 0 do
    Map.put(state, :highest_raise, amount)
  end

  def reset_highest_raise(%__MODULE__{} = state) do
    Map.put(state, :highest_raise, 0)
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

  @doc """
  Settles the hand at showdown: derives pots via `build_pots/1`, refunds
  uncalled chips to contributors, distributes each pot to its eligible
  winner(s), and zeroes the running pot.
  """
  def distribute_pots(%__MODULE__{} = state) do
    %{pots: pots, refunds: refunds} = build_pots(state)

    state
    |> apply_refunds(refunds)
    |> apply_pot_distribution(pots)
    |> Map.put(:pot, 0)
  end

  defp apply_refunds(%__MODULE__{} = state, refunds) do
    Enum.reduce(refunds, state, fn
      {_player_id, 0}, acc -> acc
      {player_id, amount}, acc -> PlayerState.add_chips(acc, player_id, amount)
    end)
  end

  defp apply_pot_distribution(%__MODULE__{} = state, pots) do
    Enum.reduce(pots, state, fn pot, acc ->
      winners = determine_winners(acc, pot.eligible_ids)
      pay_pot(acc, pot.amount, winners)
    end)
  end

  defp determine_winners(%__MODULE__{} = state, eligible_ids) do
    community = translate_cards(state.community_cards)

    # Build one {id, score} tuple per eligible player. Score is the value of the player's best hand.
    # Equal hands produce equal scores, stronger hands produce larger scores
    # Example result: scored = [{"A", 6783750}, {"B", 51234}, {"C", 51234}]
    scored =
      Enum.map(eligible_ids, fn id ->
        player = get_player(state, id)
        hole = translate_cards(player.current_hand)
        # find best possible hand for player
        {_rank, best} = Poker.best_hand(hole, community)
        # insert value of best hand into tuple for player
        {id, Poker.hand_value(best)}
      end)

    # compare eligible players' best hands and find the highest score(s)
    best_hand_score = scored |> Enum.map(fn t -> elem(t, 1) end) |> Enum.max()

    # return list of player ids whose best hand matches the highest score
    #  Output: ["B", "C"] for a tie, ["A"] for a clear winner
    scored
    |> Enum.filter(fn {_, score} -> score == best_hand_score end)
    |> Enum.map(&elem(&1, 0))
  end

  defp handle_showdown(%__MODULE__{} = state) do
    # If only one active player, skip straight to hand_finished without doing any card comparison or pot distribution
    active_count = Enum.count(state.players, &(&1.state in [:active_in_hand, :all_in]))

    # If more than one active player, deal remaining community cards (if any)
    new_state =
      if active_count > 1 and length(state.community_cards) < 5 do
        deal_community_cards(state, 5 - length(state.community_cards))
      else
        state
      end

    # and distribute pots based on hand strength
    distribute_pots(new_state)
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
          |> set_player_value(player.id, :total_contributed, 0)
          |> reset_player_state(player)
        end)

      new_state
      |> Map.put(:hands_played, new_state.hands_played + 1)
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

  def reset_has_acted(%__MODULE__{} = state) do
    updated_players =
      Enum.map(state.players, fn player ->
        %{player | has_acted: false}
      end)

    %{state | players: updated_players}
  end

  def reset_current_bet(%__MODULE__{} = state) do
    updated_players =
      Enum.map(state.players, fn player ->
        %{player | current_bet: 0}
      end)

    %{state | players: updated_players}
  end

  defp pay_pot(%__MODULE__{} = state, amount, winners) do
    num_winners = length(winners)
    leftover_amount = rem(amount, num_winners)
    share = div(amount - leftover_amount, num_winners)

    state
    |> pay_equal_shares(winners, share)
    |> pay_leftover_chips(winners, leftover_amount)
  end

  defp pay_equal_shares(state, _winners, 0), do: state

  defp pay_equal_shares(state, winners, share) do
    Enum.reduce(winners, state, fn winner_id, acc ->
      PlayerState.add_chips(acc, winner_id, share)
    end)
  end

  defp pay_leftover_chips(state, _winners, 0), do: state

  defp pay_leftover_chips(state, winners, leftover) do
    Enum.reduce(0..(leftover - 1), state, fn i, acc ->
      PlayerState.add_chips(acc, Enum.at(winners, i), 1)
    end)
  end
end
