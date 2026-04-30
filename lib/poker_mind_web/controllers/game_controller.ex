defmodule PokerMindWeb.GameController do
  use PokerMindWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game
  alias PokerMind.Engine.Match.Supervisor, as: MatchSupervisor
  alias PokerMind.Engine.TableState
  alias PokerMind.Engine.TableState.PlayerState
  alias PokerMindWeb.Schemas.ActionRequest
  alias PokerMindWeb.Schemas.BadRequest
  alias PokerMindWeb.Schemas.GameResponse
  alias PokerMindWeb.Schemas.InternalServerError
  alias PokerMindWeb.Schemas.NotFound
  alias PokerMindWeb.Schemas.StartSuiteRequest
  alias PokerMindWeb.Schemas.StartSuiteResponse
  alias PokerMindWeb.Schemas.SuitesResponse

  operation(:suites,
    summary: "List all match suites",
    responses: [
      ok: {"List of match suites and associated players", "application/json", SuitesResponse}
    ]
  )

  def suites(conn, _params) do
    json(conn, %{data: MatchSupervisor.all_match_suites()})
  end

  operation(:start_suite,
    summary: "Start a new game suite",
    request_body: {"Suite params", "application/json", StartSuiteRequest},
    responses: [
      ok: {"Started new suite", "application/json", StartSuiteResponse},
      bad_request: {"Bad request", "application/json", BadRequest}
    ]
  )

  def start_suite(conn, %{"players" => players} = params) do
    with :ok <- validate_players(players), :ok <- maybe_validate_num_games(params) do
      num_games =
        case Map.get(params, "num_games") do
          nil -> 10
          val when is_integer(val) -> val
          val -> Integer.parse(val)
        end

      suite_id = UUID.uuid4()
      {:ok, _pid, suite_id} = MatchSupervisor.start_match_suite(suite_id, players, num_games)
      json(conn, %{suite_id: suite_id})
    else
      {:error, msg} -> conn |> put_status(:bad_request) |> json(%{error: msg})
    end
  end

  def start_suite(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "players are required"})
  end

  operation(:next_games,
    summary: "List upcoming games",
    parameters: [
      player_id: [in: :query, description: "Your ID", type: :string],
      suite_id: [in: :query, description: "Suite ID", type: :string]
    ],
    responses: [
      ok: {"List of games", "application/json", GameResponse},
      not_found: {"Not found", "application/json", NotFound},
      bad_request: {"Bad request", "application/json", BadRequest}
    ]
  )

  def next_games(conn, %{"player_id" => player_id, "suite_id" => suite_id}) do
    coordinator_id = Coordinator.id(suite_id)

    case Coordinator.next_games(coordinator_id, player_id) do
      {:error, msg} when msg in [:game_not_found, :coordinator_not_found] ->
        error_msg = msg |> to_string() |> String.replace("_", " ")

        conn
        |> put_status(:not_found)
        |> json(%{error: error_msg})

      games ->
        mapped_games = Enum.map(games, fn game -> map_tablestate(game, player_id) end)
        json(conn, %{data: mapped_games})
    end
  end

  def next_games(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "player_id and suite_id are required"})
  end

  operation(:perform_action,
    summary: "Submit a player action",
    request_body: {"Action params", "application/json", ActionRequest},
    responses: [
      ok: {"Updated game state", "application/json", PokerMindWeb.Schemas.Game},
      not_found: {"Not found", "application/json", NotFound},
      bad_request: {"Bad request", "application/json", BadRequest},
      internal_server_error: {"Internal server error", "application/json", InternalServerError}
    ]
  )

  def perform_action(conn, %{
        "player_id" => player_id,
        "game_id" => game_id,
        "action" => action
      }) do
    case Game.apply_action(game_id, action, player_id) do
      {:ok, state} ->
        mapped_state = %{state | game: map_tablestate(state.game, player_id)}
        json(conn, %{data: mapped_state})

      {:error, :game_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Game not found"})

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
      state: player.state,
      has_acted: player.has_acted,
      current_bet: player.current_bet
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
      current_player_id: tablestate.current_player_id,
      highest_raise: tablestate.highest_raise
    }
  end

  defp validate_players(players) do
    cond do
      players == nil -> {:error, "players were not set, please provude atleast 2"}
      players == [] -> {:error, "got empty list of players, please provide atleast 2"}
      length(players) == 1 -> {:error, "got a list with 1 player, please provide atleast 2"}
      Enum.any?(players, &(not is_binary(&1))) -> {:error, "players should be a list of strings"}
      true -> :ok
    end
  end

  defp maybe_validate_num_games(params) do
    num_games = Map.get(params, "num_games")

    cond do
      is_nil(num_games) ->
        :ok

      is_integer(num_games) ->
        :ok

      Integer.parse(num_games) == :error ->
        {:error, "num_games is not a textual representation of an integer"}

      true ->
        :ok
    end
  end
end
