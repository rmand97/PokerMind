defmodule PokerMind.Engine.TableState do
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
    # big blind
    :small_blind_id,
    # whose turn
    :current_player_id,
    # bet to match
    :highest_raise,
    :big_blind_amount
  ]

  def new(id) when is_binary(id) do
    # when we initialize a new table, highest_raise and big_blind_amount is the same
    big_blind_amount = 100

    %__MODULE__{
      id: id,
      phase: :pre_flop,
      players: [],
      pot: 0,
      deck: [],
      community_cards: [],
      highest_raise: big_blind_amount,
      big_blind_amount: big_blind_amount
    }
  end

  def init(%__MODULE__{} = state, init_players) when is_list(init_players) do
    state
    |> initialize_players(init_players)
    |> new_deck()
    |> deal_cards()
    |> set_blinds()
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
    new_player =
      PlayerState.new(new_player_id, 100)

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

  defp set_blinds(%__MODULE__{} = state) do
    small_blind = Enum.random(state.players)

    state
    |> Map.put(:small_blind_id, small_blind.id)
    |> advance_player(:current_player_id, small_blind.id)
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
    # TODO: Extract as compile-time constants
    suits = [:hearts, :diamonds, :clubs, :spades]
    ranks = [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace]

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
        {drawn, remaining} = Enum.split(acc, 2)
        {%{player | current_hand: drawn}, remaining}
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
    :showdown => [:finished]
  }

  # TODO opdater så det passer med ovenstående valid transitions
  def next_phase(%__MODULE__{} = state) do
    case state.phase do
      :pre_flop -> :flop
      :flop -> :turn
      :turn -> :river
      :river -> :showdown
    end
  end

  def advance_phase(%__MODULE__{} = state, next_phase) when is_atom(next_phase) do
    if next_phase in Map.get(@valid_transitions, state.phase, []) do
      Map.put(state, :phase, next_phase)
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
end
