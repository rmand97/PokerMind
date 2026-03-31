defmodule PokerMind.TableState do
  @enforce_keys [:id, :phase, :players, :pot, :deck, :community_cards]
  defstruct [
    :id,              # table-id
    :phase,           # :pre_flop | :flop | :turn | :river | :showdown
    :players,         # list of player states
    :pot,             # current pot
    :deck,            # remaining cards
    :community_cards, # cards on the table
    :current_player,  # whose turn
    :current_bet      # bet to match
  ]

  def new() do
    %__MODULE__{id: "123", phase: :pre_flop, players: [], pot: 0, deck: [], community_cards: []}
  end

  def init(state, init_players) when is_list(init_players) do
    state
    |> initialize_players(init_players)
    # |> set_blinds()
    |> new_deck()
    # |> deal_cards()
  end

  defp initialize_players(table_state, []) do
    table_state
  end

  defp initialize_players(table_state, [hd | rest]) do
    initialize_players(add_player(table_state, hd), rest)
  end

  defp add_player(%{players: players} = tablestate, %{stack_size: _} = new_player) when is_list(players) do
    Map.put(tablestate, :players, [new_player | players])
  end

  defp new_deck(table_state) do
    suits = [:hearts, :diamonds, :clubs, :spades]
    ranks = [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace]

    deck = for suit <- suits, rank <- ranks do
      %{rank: rank, suit: suit}
    end
    |> Enum.shuffle()
    Map.put(table_state, :deck, deck)
  end

  defp deal_community_cards(table_state, n) do
    {drawn, remaining} = Enum.split(table_state.deck, n)
    table_state
    |> Map.put(:deck, remaining)
    |> Map.put(:community_cards, drawn)
  end
end
