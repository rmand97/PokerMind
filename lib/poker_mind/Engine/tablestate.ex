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
    # whose turn
    :current_player,
    # bet to match
    :current_bet
  ]

  def new() do
    %__MODULE__{id: "123", phase: :pre_flop, players: [], pot: 0, deck: [], community_cards: []}
  end

  def init(state, init_players) when is_list(init_players) do
    state
    |> initialize_players(init_players)
    # |> set_blinds()
    |> new_deck()
    |> deal_cards()
  end

  defp initialize_players(table_state, []) do
    table_state
  end

  defp initialize_players(table_state, [hd | rest]) do
    initialize_players(add_player(table_state, hd), rest)
  end

  defp add_player(%{players: players} = tablestate, %{stack_size: _} = new_player)
       when is_list(players) do
    Map.put(tablestate, :players, [new_player | players])
  end

  defp new_deck(table_state) do
    suits = [:hearts, :diamonds, :clubs, :spades]
    ranks = [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace]

    deck =
      for suit <- suits, rank <- ranks do
        %{rank: rank, suit: suit}
      end
      |> Enum.shuffle()

    table_state
    |> Map.put(:deck, deck)
  end

  def deal_cards(table_state) do
    {updated_players, remaining_deck} =
      Enum.map_reduce(table_state.players, table_state.deck, fn player, acc ->
        {drawn, remaining} = Enum.split(acc, 2)
        {Map.put(player, :cards, drawn), remaining}
      end)

    table_state
    |> Map.put(:deck, remaining_deck)
    |> Map.put(:players, updated_players)
  end
end
