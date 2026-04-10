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
    # whether player has acted in current betting round
    :has_acted
  ]

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
end
