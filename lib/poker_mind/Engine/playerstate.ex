defmodule PokerMind.Engine.TableState.PlayerState do
  alias PokerMind.Engine.TableState

  @enforce_keys [:id, :remaining_chips]
  defstruct [
    # unique player identifier
    :id,
    # list of two %Card{} structs, nil between hands
    :current_hand,
    :remaining_chips,
    # :active_in_hand | :inactive_in_hand | :out_of_chips | all_in
    :state,
    :current_bet,
    # whether player has acted in current betting round
    :has_acted
  ]

  def new(id, remaining_chips) do
    %__MODULE__{
      id: id,
      remaining_chips: remaining_chips,
      state: :active_in_hand,
      current_bet: 0,
      has_acted: false
    }
  end

  def reset_has_acted(%TableState{} = state) do
    updated_players =
      Enum.map(state.players, fn player ->
        %{player | has_acted: false}
      end)

    %{state | players: updated_players}
  end

  def set_player_value(player, key, new_value) do
    Map.put(player, key, new_value)
  end

  def deduct_chips(%TableState{} = state, player_id, amount)
      when is_integer(amount) and amount > 0 do
    update_in(
      state,
      [Access.key(:players), Access.find(&(&1.id == player_id)), Access.key(:remaining_chips)],
      fn current_chips -> current_chips - amount end
    )
  end

  def update_current_bet(%TableState{} = state, player_id, amount)
      when is_integer(amount) and amount > 0 do
    update_in(
      state,
      [Access.key(:players), Access.find(&(&1.id == player_id)), Access.key(:current_bet)],
      fn current_bet -> current_bet + amount end
    )
  end
end
