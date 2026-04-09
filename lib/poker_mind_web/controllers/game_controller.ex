defmodule PokerMindWeb.GameController do
  use PokerMindWeb, :controller

  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game

  def next_games(conn, %{"player_id" => player_id, "suite_id" => suite_id}) do
    coordinator_id = Coordinator.id(suite_id)
    {games, _count} = Coordinator.next_games(coordinator_id, player_id)
    json(conn, %{data: games})
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
        json(conn, %{data: state})

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
end
