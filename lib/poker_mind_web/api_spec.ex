defmodule PokerMindWeb.ApiSpec do
  alias OpenApiSpex.Info
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Paths
  alias OpenApiSpex.Server
  alias OpenApiSpex.Components
  alias OpenApiSpex.SecurityScheme
  alias PokerMindWeb.Endpoint
  alias PokerMindWeb.Router
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "PokerMind",
        version: "0.1.0"
      },
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{"authorization" => %SecurityScheme{type: "apiKey", in: "header", name: "authorization"}}
      },
      security: [%{"authorization" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
