defmodule PokerMind.Actions do
  alias PokerMind.Engine.TableState

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

  def apply_action(%TableState{} = state, :fold, player_id) do
    with :ok <- validate_turn(player_id) do
      state
      |> set_player_state(InactiveInHand)
      |> advance_player_turn(:fold)
    end
  end

  defp set_player_state(%TableState{} = state, new_player_state) do
    # get state.current_player
    # set current.player.player_state = new_player_state
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

  # defp validate_turn(player_id) do
  #   if player_id != TableState.current_player() do
  #     {:error, {:action_out_of_turn, "player_id != current_player - its not your turn"}}
  #   else
  #     :ok
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

  # TODO
  defp advance_player_turn(%TableState{} = state) do
    # Check if any players have yet to act

    # increment player turn to any of those players
    next_state = advance_player()

    # check new current player state
    new_current_player.player_state = ActiveInHand && has(not acted(yet))
    state.advance_player()

    # of course right to act resets if anyone bets

    # if no more player_turns
    state.advance_phase(current_phase)
  end
end
