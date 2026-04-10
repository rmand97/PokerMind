defmodule PokerMindWeb.GameController do
  use PokerMindWeb, :controller

  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState

  def next_games(conn, %{"player_id" => player_id, "suite_id" => suite_id}) do
    coordinator_id = Coordinator.id(suite_id)

    games =
      coordinator_id
      |> Coordinator.next_games(player_id)

    mapped_games =
      Enum.map(games, fn game ->
        map_tablestate(game, player_id)
      end)

    json(conn, %{data: mapped_games})
  end

  def next_games(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "player_id and suite_id are required"})
  end

  def perform_action(conn, %{
        "player_id" => player_id,
        "game_id" => game_id,
        "action" => action
      }) do
    case Game.apply_action(game_id, action, player_id) do
      {:ok, state} ->
        mapped_state = %{state | game: map_tablestate(state.game, player_id)}
        json(conn, %{data: mapped_state})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: to_string(reason)})

      other ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "unexpected response: #{inspect(other)}"})
    end
  end

  def perform_action(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "player_id, game_id and action are required"})
  end

  # TODO: This is a draft
  defp map_playerstate(%PlayerState{} = player, calling_player_id) do
    mapped_player_state = %{
      id: player.id,
      remaining_chips: player.remaining_chips,
      player_state: player.state,
      has_acted: player.has_acted
    }

    if player.id == calling_player_id do
      Map.put(mapped_player_state, :current_hand, player.current_hand)
    else
      mapped_player_state
    end
  end

  defp map_tablestate(%TableState{} = tablestate, player_id) do
    player =
      tablestate.players
      |> Enum.find(fn player -> player.id == player_id end)
      |> map_playerstate(player_id)

    other_players =
      tablestate.players
      |> Enum.filter(fn player -> player.id != player_id end)
      |> Enum.map(fn player -> map_playerstate(player, player_id) end)

    %{
      id: tablestate.id,
      player: player,
      other_players: other_players,
      phase: tablestate.phase,
      pot: tablestate.pot,
      community_cards: tablestate.community_cards,
      current_player: tablestate.current_player.id,
      current_bet: tablestate.current_bet
    }
  end
end
