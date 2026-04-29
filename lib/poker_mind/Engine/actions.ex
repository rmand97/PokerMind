defmodule PokerMind.Engine.Actions do
  alias PokerMind.Engine.TableState

  def apply_action(%TableState{phase: :game_finished}, _action) do
    {:error, {:game_is_finished, "Game is finished, no more actions can be performed"}}
  end

  def apply_action(%TableState{} = state, %{type: :raise, player_id: player_id, amount: amount}) do
    with :ok <- validate_turn(state, player_id),
         :ok <- validate_amount(state, player_id, amount),
         :ok <- validate_raise(state, player_id, amount) do
      state
      |> TableState.add_to_pot(player_id, amount)
      |> TableState.update_highest_raise(amount)
      |> TableState.reset_has_acted()
      |> advance_player_turn(:raise)
    end
  end

  def apply_action(%TableState{} = state, %{type: :fold, player_id: player_id})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id),
         :ok <- validate_fold(state, player_id) do
      state
      |> TableState.set_player_value(player_id, :state, :inactive_in_hand)
      |> advance_player_turn(:fold)
    end
  end

  def apply_action(%TableState{} = state, %{type: :call, player_id: player_id, amount: amount})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id),
         :ok <- validate_call(state, amount),
         :ok <- validate_amount(state, player_id, amount) do
      state
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

  def apply_action(%TableState{} = state, %{type: :all_in, player_id: player_id})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id) do
      %{remaining_chips: chips, current_bet: bet} = TableState.get_player(state, player_id)
      all_in_amount = chips + bet

      state
      |> TableState.set_player_value(player_id, :state, :all_in)
      |> TableState.add_to_pot(player_id, all_in_amount)
      |> over_the_top_all_in(all_in_amount)
      |> advance_player_turn(:all_in)
    end
  end

  def apply_action(_state, _action) do
    {:error, {:invalid_action, "Action is not supported"}}
  end

  # Over-the-top all-in re-opens action: updates highest_raise and clears
  # has_acted so remaining active players must respond. Short or matching
  # all-ins (amount <= highest_raise) leave those unchanged.
  defp over_the_top_all_in(%TableState{} = state, all_in_amount) do
    if all_in_amount > state.highest_raise do
      state
      |> TableState.update_highest_raise(all_in_amount)
      |> TableState.reset_has_acted()
    else
      state
    end
  end

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

  defp validate_amount(state, player_id, amount) when is_integer(amount) do
    player = TableState.get_player(state, player_id)

    cond do
      amount < player.remaining_chips and amount > 0 ->
        :ok

      amount == player.remaining_chips ->
        {:error,
         "Action requires all remaining chips - if you want to go all in use the all_in action type"}

      true ->
        {:error,
         "Action requires more chips than player has remaining - if you want to go all in use the all_in action type"}
    end
  end

  defp validate_fold(%TableState{players: players}, player_id) do
    other_players_still_active? =
      Enum.any?(players, fn p ->
        p.id != player_id and p.state in [:active_in_hand, :all_in]
      end)

    if other_players_still_active? do
      :ok
    else
      {:error,
       {:cannot_fold_last_player, "Cannot fold when no other players are still in the hand"}}
    end
  end

  defp validate_call(%TableState{highest_raise: highest_raise}, amount) when is_integer(amount) do
    if amount == highest_raise do
      :ok
    else
      {:error,
       {:invalid_call_amount, "Call amount #{amount} must match highest raise #{highest_raise}"}}
    end
  end

  defp validate_raise(state, player_id, amount) do
    player = TableState.get_player(state, player_id)

    cond do
      player.current_bet == amount ->
        {:error, "Current_bet = new raise amount - did we already perform this bet?"}

      amount < 2 * state.big_blind_amount ->
        {:error, "Not a valid raise - assume bet size too small"}

      amount >= 2 * state.big_blind_amount ->
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
      |> TableState.reset_has_acted()
      |> TableState.reset_current_bet()
      |> TableState.reset_highest_raise()
      |> TableState.advance_phase(next_phase)
      |> TableState.set_current_player_for_phase()
    else
      next_player_id =
        TableState.find_next_active_player_id(updated_state, state.current_player_id)

      %{updated_state | current_player_id: next_player_id}
    end
  end
end
