defmodule PokerMindWeb.ApiAuth do
  import Plug.Conn

  def fetch_token_and_verify(conn, _opts) do
    with [secret] <- get_req_header(conn, "authorization"),
         true <- secret == Application.get_env(:poker_mind, :api_auth_secret) do
      conn
    else
      _ ->
        conn
        |> send_resp(:unauthorized, "No access for you my friend")
        |> halt()
    end
  end
end
