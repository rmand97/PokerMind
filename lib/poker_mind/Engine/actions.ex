defmodule PokerMind.Engine.Actions do
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

  # def apply_action(%TableState{} = state, {:raise, amount}, player_id) do
  #   with :ok <- validate_turn(player_id) do
  #     #  :ok <- validate_raise(phase, player_id, amount) do
  #     state.phase
  #     |> deduct_chips(player_id, amount)
  #     |> add_to_pot(amount)
  #     |> update_current_raise(amount)
  #     |> advance_player_turn(:raise)
  #   end
  # end

  def apply_action(%TableState{} = state, :fold, player_id) when is_binary(player_id) do
    with :ok <- validate_turn(state, player_id) do
      state
      |> TableState.set_player_value(player_id, :state, :inactive_in_hand)
      |> advance_player_turn(:fold)
    end
  end

  # def apply_action(%TableState{} = state, :call, amount, player_id) do
  #   with :ok <- validate_turn(player_id) do
  #     state.phase
  #     |> deduct_chips(player_id, amount)
  #     |> add_to_pot(amount)
  #     |> advance_player_turn(:call)
  #   end
  # end

  # def apply_action(%TableState{} = state, :check, amount, player_id) do
  #   with :ok <- validate_turn(player_id),
  #        :ok <- amount == nil do
  #     state.phase
  #     |> deduct_chips(player_id, amount)
  #     |> add_to_pot(amount)
  #     |> advance_player_turn(:check)
  #   end
  # end

  # def apply_action(%TableState{} = state, amount, player_id) do
  #     #TODO handle invalid action call
  # end

  # move to table state
  defp validate_turn(state, player_id) when is_binary(player_id) do
    if player_id != state.current_player.id do
      {:error, {:action_out_of_turn, "player_id != current_player - its not your turn"}}
    else
      :ok
    end
  end

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

  # TODO
  defp advance_player_turn(%TableState{} = state, _action) do
    if TableState.round_complete?(state) do
      next_phase = TableState.next_phase(state.phase)

      state
      |> PlayerState.reset_has_acted()
      |> TableState.advance_phase(next_phase)
      |> TableState.set_current_player_for_phase()
    else
      next = TableState.find_next_active_player(state, state.current_player)
      %{state | current_player: next}
    end
  end
end
