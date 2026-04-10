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
    :small_blind,
    # whose turn
    :current_player,
    # bet to match
    :current_bet
  ]

  def new(id) when is_binary(id) do
    %__MODULE__{id: id, phase: :pre_flop, players: [], pot: 0, deck: [], community_cards: []}
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
    # TODO: remaining_chips is hardcoded to 100
    Map.put(state, :players, [
      %PlayerState{player_id: new_player_id, remaining_chips: 100} | state.players
    ])
  end

  defp set_blinds(%__MODULE__{} = state) do
    small_blind = Enum.random(state.players)

    state
    |> Map.put(:small_blind, small_blind)
    |> advance_player(:current_player, small_blind)
    |> advance_player()
  end

  # TODO validation function på player_state skal være en af følgende
  # :active_in_hand | :inactive_in_hand | :out_of_chips

  def advance_player(state, key \\ :current_player, player \\ nil)
      when is_nil(player) or is_struct(player, PlayerState) do
    from_player =
      case player do
        nil -> state.current_player
        player -> player
      end

    index = Enum.find_index(state.players, fn p -> p == from_player end)
    next_player = Enum.at(state.players, rem(index + 1, length(state.players)))

    state
    |> Map.put(key, next_player)
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
      Enum.map_reduce(state.players, state.deck, fn player, acc ->
        {drawn, remaining} = Enum.split(acc, 2)
        {Map.put(player, :cards, drawn), remaining}
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

  def advance_phase(%__MODULE__{} = state, next_phase) when is_atom(next_phase) do
    if next_phase in Map.get(@valid_transitions, state.phase, []) do
      Map.put(state, :phase, next_phase)
    else
      {:error, {:invalid_transition, state.phase, next_phase}}
    end
  end
end
