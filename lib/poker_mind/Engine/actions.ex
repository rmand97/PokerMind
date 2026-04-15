defmodule PokerMind.Engine.Actions do
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

  def apply_action(%TableState{} = state, %{type: :raise, player_id: player_id, amount: amount}) do
    with :ok <- validate_turn(state, player_id),
         :ok <- validate_amount(state, player_id, amount),
         :ok <- validate_raise(state, player_id, amount) do
      state.phase
      |> TableState.add_to_pot(player_id, amount)
      |> TableState.update_highest_raise(amount)
      |> advance_player_turn(:raise)
    end
  end

  def apply_action(%TableState{} = state, %{type: :fold, player_id: player_id})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id) do
      state
      |> TableState.set_player_value(player_id, :state, :inactive_in_hand)
      |> advance_player_turn(:fold)
    end
  end

  def apply_action(%TableState{} = state, %{type: :call, player_id: player_id, amount: amount})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id),
         :ok <- validate_amount(state, player_id, amount) do
      state.phase
      |> TableState.add_to_pot(player_id, amount)
      |> advance_player_turn(:call)
    end
  end

  def apply_action(%TableState{} = state, %{type: :check, player_id: player_id})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id) do
      player = Enum.find(state.players, &(&1.id == player_id))

      if state.highest_raise != player.current_bet do
        {:error,
         {:current_bet_too_low,
          "Cannot check because your current bet #{player.current_bet} does not match the required highest raise #{state.highest_raise}"}}
      else
        state
        |> advance_player_turn(:check)
      end
    end
  end

  # def apply_action(%TableState{} = state, amount, player_id) do
  #     #TODO handle invalid action call
  # end

  # move to table state
  defp validate_turn(state, player_id) when is_binary(player_id) do
    player = TableState.get_player(state, player_id)

    cond do
      player == nil ->
        {:error, {:invalid_player, "Player not found at the table"}}

      player.state != :active_in_hand ->
        {:error, {:player_not_active, "Player is not active in the hand"}}

      player.has_acted ->
        {:error, {:player_already_acted, "Player has already acted in this betting round"}}

      player_id != state.current_player_id ->
        {:error, {:action_out_of_turn, "Awaiting action from player #{state.current_player_id}"}}

      true ->
        :ok
    end
  end

  defp validate_amount(state, player_id, amount) when is_binary(amount) do
    player = TableState.get_player(state, player_id)

    cond do
      amount <= player.remaining_chips -> :ok
      amount > 0 -> :ok
      true -> {:error, "Action requires more chips than player has remaining"}
    end
  end

  defp validate_raise(state, player_id, amount) do
    player = TableState.get_player(state, player_id)

    cond do
      player.current_bet == amount ->
        {:error, "Current_bet = new raise amount - did we already perform this bet?"}

      amount < 2 * state.highest_raise ->
        {:error, "Not a valid raise - assume bet size too small"}

      amount >= 2 * state.highest_raise ->
        :ok

      true ->
        {:error, "Not a valid action"}
    end
  end

  defp advance_player_turn(%TableState{} = state, _action) do
    updated_state = TableState.complete_current_player_turn(state)

    if TableState.round_complete?(updated_state) do
      next_phase = TableState.next_phase(state)

      state
      |> PlayerState.reset_has_acted()
      |> TableState.advance_phase(next_phase)
      |> TableState.set_current_player_for_phase()
    else
      next_player = TableState.find_next_active_player(updated_state, state.current_player_id)
      %{updated_state | current_player_id: next_player.id}
    end
  end
end
