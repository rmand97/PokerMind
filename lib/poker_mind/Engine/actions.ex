defmodule PokerMind.Engine.Actions do
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

  # def apply_action(%TableState{} = state, %{type: :raise, player_id: player_id, amount: amount}) do
  #   with :ok <- validate_turn(player_id) do
  #     #  :ok <- validate_raise(phase, player_id, amount) do
  #     state.phase
  #     |> deduct_chips(player_id, amount)
  #     |> add_to_pot(amount)
  #     |> update_current_raise(amount)
  #     |> advance_player_turn(:raise)
  #   end
  # end

  def apply_action(%TableState{} = state, %{type: :fold, player_id: player_id})
      when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id) do
      state
      |> TableState.set_player_value(player_id, :state, :inactive_in_hand)
      |> advance_player_turn(:fold)
    end
  end

  # def apply_action(%TableState{} = state, %{type: :call, player_id: player_id, amount: amount})
  #     when is_binary(player_id) do
  #   with :ok <- validate_turn(player_id) do
  #     state.phase
  #     |> deduct_chips(player_id, amount)
  #     |> add_to_pot(amount)
  #     |> advance_player_turn(:call)
  #   end
  # end

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
    player = Enum.find(state.players, &(&1.id == player_id))

    if player_id != state.current_player_id or player.has_acted do
      {:error, {:action_out_of_turn, "It's not your turn"}}
    else
      :ok
    end
  end

  # defp validate_amount(state, player_id, amount) do
  #   player = Enum.find(state.players, &(&1.id == player_id))

  #   cond do
  #     not is_integer(amount) ->
  #       {:error, {:not_integer, "Only supports integers, got: #{inspect(amount)}"}}

  #     amount <= 0 ->
  #       {:error, {:not_positive, "Only supports positive integers, got: #{inspect(amount)}"}}

  #     player.remaining_chips < amount ->
  #       {:error,
  #        {:missing_chips,
  #         "Player #{player_id} does not have enough chips left. Has: #{player.remaining_chips}, bid: #{amount}"}}

  #     true ->
  #       :ok
  #   end
  # end

  # pseudo kode #TODO
  # defp validate_raise(player_id, amount \\ 0) do
  #   if(amount > {2 * TableState.big_blind()}) do
  #     # raise større end min raise
  #     :ok
  #   else
  #     if amount < TableState.players(player_id).stack_size do
  #       # raise mindre end stack
  #       # Check if divisible by chip denomination
  #       :ok
  #     else
  #       if(amount == TableState.players(player_id).stack_size) do
  #         # all in
  #         :ok
  #       else
  #         {:error, "Bet larger than stack size"}
  #       end
  #     end
  #   end
  # end

  # input: player_id, amount
  # defp deduct_chips(player_id, amount) do
  #   # TODO
  #   TableState.player(player_id).stack_size = TableState.player(player_id).stack_size - amount
  # end

  # defp add_to_pot(amount) do
  #   # TODO
  #   TableState = TableState.Pot + amount
  # end

  # defp update_current_raise(amount) do
  #   # TODO
  #   TableState.current_bet = amount
  # end

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
