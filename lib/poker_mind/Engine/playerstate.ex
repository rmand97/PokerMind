defmodule PokerMind.Engine.TableState.PlayerState do
  @enforce_keys [:player_id, :remaining_chips]
  defstruct [
    # unique player identifier
    :player_id,
    # list of two %Card{} structs, nil between hands
    :current_hand,
    :remaining_chips,
    # :active_in_hand | :inactive_in_hand | :out_of_chips
    :player_state,
    # whether player has acted in current betting round
    :has_acted
  ]
end
