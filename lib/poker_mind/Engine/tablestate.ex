defmodule PokerMind.Engine.TableState do
  @enforce_keys [:id, :phase, :players, :pot, :deck, :community_cards]
  defstruct [
    # table-id
    :id,
    # :pre_flop | :flop | :turn | :river | :showdown
    :phase,
    # :stack_size | :cards
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

  def new() do
    # TODO: change hardcode of id
    %__MODULE__{id: "123", phase: :pre_flop, players: [], pot: 0, deck: [], community_cards: []}
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

  defp initialize_players(%__MODULE__{} = state, [hd | rest]) do
    initialize_players(add_player(state, hd), rest)
  end

  defp add_player(%__MODULE__{} = state, new_player)
       when is_list(state.players) do
    Map.put(state, :players, [new_player | state.players])
  end

  defp set_blinds(%__MODULE__{} = state) do
    small_blind = Enum.random(state.players)

    state
    |> Map.put(:small_blind, small_blind)
    |> advance_player(:current_player, small_blind)
    |> advance_player()
  end

  def advance_player(%__MODULE__{} = state, key \\ :current_player, player \\ nil) do
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
end
