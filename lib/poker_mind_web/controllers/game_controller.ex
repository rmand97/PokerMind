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

    # TODO: Filter what information the player gets
    mapped_games =
      Enum.map(games, fn game ->
        map_tablestate(game)
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
        mapped_state = %{state | game: map_tablestate(state.game)}
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
  defp map_playerstate(%PlayerState{} = player) do
    %{player_id: player.player_id}
  end

  defp map_tablestate(%TableState{} = tablestate) do
    players = Enum.map(tablestate.players, fn player -> map_playerstate(player) end)
    %{id: tablestate.id, players: players}
  end
end
