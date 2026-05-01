defmodule PokerMind.Engine.Match.GameTest do
  use ExUnit.Case, async: true

  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Coordinator

  setup do
    suite_id = UUID.uuid4()
    coordinator_id = Coordinator.id(suite_id)
    game_id = Game.id(suite_id, 1)
    player = "stine"

    start_supervised!(
      Supervisor.child_spec(
        {Coordinator, name: coordinator_id, num_games: 1, players: [player]},
        id: {Coordinator, coordinator_id}
      )
    )

    start_supervised!(
      Supervisor.child_spec(
        {Game, name: game_id, players: [player], coordinator_id: coordinator_id},
        id: game_id
      )
    )

    %{
      game_id: game_id,
      coordinator_id: coordinator_id,
      player: player,
      suite_id: suite_id
    }
  end

  describe "get_state/1" do
    test "returns game state", %{game_id: game_id} do
      state = Game.get_state(game_id)

      assert %{game: game, coordinator_id: _, id: ^game_id, finished?: false} = state
      assert game != nil
    end
  end

  describe "apply_action/2" do
    test "applies a valid action and returns updated game state", %{game_id: game_id} do
      state = Game.get_state(game_id)
      current_player_id = state.game.current_player_id

      assert {:ok, new_game_state} =
               Game.apply_action(game_id, %{action: :check, player_id: current_player_id})

      assert %PokerMind.Engine.TableState{} = new_game_state
    end

    test "returns error when it is not the player's turn", %{game_id: game_id, player: player} do
      state = Game.get_state(game_id)

      if state.game.current_player_id == player do
        assert {:ok, _} = Game.apply_action(game_id, %{action: :check, player_id: player})
      else
        assert {:error, _} =
                 Game.apply_action(game_id, %{action: :check, player_id: player})
      end
    end

    test "returns {:error, :game_finished} when game is already finished", %{game_id: game_id} do
      finish_game(game_id)

      state = Game.get_state(game_id)
      assert state.finished?

      assert {:error, :game_finished} =
               Game.apply_action(game_id, %{action: :check, player_id: "stine"})
    end

    test "notifies coordinator of next player after action", %{
      game_id: game_id,
      coordinator_id: coordinator_id
    } do
      state = Game.get_state(game_id)
      current_player_id = state.game.current_player_id

      {:ok, new_game_state} =
        Game.apply_action(game_id, %{action: :check, player_id: current_player_id})

      unless new_game_state.phase == :game_finished do
        coordinator_state = Coordinator.get_state(coordinator_id)
        game_entry = coordinator_state.games[game_id]
        assert game_entry.next_player == new_game_state.current_player_id
      end
    end

    test "notifies coordinator when game finishes", %{
      game_id: game_id,
      coordinator_id: coordinator_id
    } do
      finish_game(game_id)

      coordinator_state = Coordinator.get_state(coordinator_id)
      game_entry = coordinator_state.games[game_id]

      assert game_entry.finished?
      assert game_entry.winner != nil
      assert is_nil(game_entry.next_player)
    end
  end

  describe "init notifies coordinator" do
    test "game registers itself as ready with the coordinator on init", %{
      game_id: game_id,
      coordinator_id: coordinator_id
    } do
      coordinator_state = Coordinator.get_state(coordinator_id)

      assert coordinator_state.all_games_ready?
      assert Map.has_key?(coordinator_state.games, game_id)
      assert coordinator_state.games[game_id].ready
    end
  end

  describe "multi-player game" do
    setup do
      suite_id = UUID.uuid4()
      coordinator_id = Coordinator.id(suite_id)
      game_id = Game.id(suite_id, 1)
      players = ["stine", "rolf"]

      start_supervised!(
        Supervisor.child_spec(
          {Coordinator, name: coordinator_id, num_games: 1, players: players},
          id: {Coordinator, coordinator_id}
        )
      )

      start_supervised!(
        Supervisor.child_spec(
          {Game, name: game_id, players: players, coordinator_id: coordinator_id},
          id: game_id
        )
      )

      %{
        game_id: game_id,
        coordinator_id: coordinator_id,
        players: players
      }
    end

    test "current player changes after an action", %{game_id: game_id} do
      state = Game.get_state(game_id)
      first_player = state.game.current_player_id

      {:ok, new_game_state} =
        Game.apply_action(game_id, %{action: :call, player_id: first_player})

      unless new_game_state.phase == :game_finished do
        assert new_game_state.current_player_id != first_player
      end
    end

    test "returns error for invalid action from wrong player", %{
      game_id: game_id,
      players: players
    } do
      state = Game.get_state(game_id)
      current = state.game.current_player_id
      wrong_player = Enum.find(players, fn p -> p != current end)

      assert {:error, _} =
               Game.apply_action(game_id, %{action: :call, player_id: wrong_player})
    end
  end

  describe "ensure_exists" do
    test "get_state/1 returns {:error, :game_not_found} when game does not exist" do
      non_existing_id = UUID.uuid4()
      assert {:error, :game_not_found} = Game.get_state(non_existing_id)
    end

    test "apply_action/2 returns {:error, :game_not_found} when game does not exist" do
      non_existing_id = UUID.uuid4()

      assert {:error, :game_not_found} =
               Game.apply_action(non_existing_id, %{action: :fold, player_id: "stine"})
    end
  end

  # Play actions untill game is finnished
  defp finish_game(game_id, max_iterations \\ 100) do
    Enum.reduce_while(1..max_iterations, nil, fn _i, _acc ->
      state = Game.get_state(game_id)

      if state.finished? do
        {:halt, :finished}
      else
        current = state.game.current_player_id

        actions = [:check, :call, :fold]

        result =
          Enum.reduce_while(actions, :stuck, fn action, _acc ->
            case Game.apply_action(game_id, %{action: action, player_id: current}) do
              {:ok, %{phase: :game_finished}} -> {:halt, {:done, :finished}}
              {:ok, _} -> {:halt, {:done, :continuing}}
              {:error, _} -> {:cont, :stuck}
            end
          end)

        case result do
          {:done, :finished} -> {:halt, :finished}
          {:done, :continuing} -> {:cont, :continuing}
          :stuck -> {:halt, :stuck}
        end
      end
    end)
  end
end
