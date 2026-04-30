defmodule PokerMindWeb.Schemas do
  alias OpenApiSpex.Schema

  defmodule Card do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        rank: %Schema{type: :integer},
        suit: %Schema{type: :string}
      }
    })
  end

  defmodule Player do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Player ID"},
        remaining_chips: %Schema{type: :integer, description: "Remaining chips"},
        state: %Schema{type: :string, description: "Player state"},
        has_acted: %Schema{
          type: :boolean,
          description: "Whether the player has acted in this betting round"
        },
        current_bet: %Schema{type: :integer, description: "Your current bet"}
      }
    })
  end

  defmodule Game do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Game",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "Game ID"},
        player: %Schema{
          allOf: [
            Player,
            %Schema{
              type: :object,
              properties: %{
                current_hand: %Schema{type: :array, items: Card, description: "Your Hand"}
              }
            }
          ]
        },
        other_players: %Schema{
          type: :array,
          items: Player,
          description: "List of other players in the game"
        },
        phase: %Schema{type: :string, description: "Phase of the current betting round"},
        pot: %Schema{type: :integer, description: "Current size of the pot"},
        community_cards: %Schema{type: :array, items: Card, description: "Cards on the table"},
        current_player_id: %Schema{type: :string, description: "Current player turn"},
        highest_raise: %Schema{type: :integer, description: "Current bet to match"}
      }
    })
  end

  defmodule GameResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GameResponse",
      description: "A list of upcoming games",
      type: :object,
      properties: %{
        games: %Schema{
          type: :array,
          items: Game
        },
        all_games_finished: %Schema{
          type: :boolean,
          description: "All games in the suite are finished"
        }
      }
    })
  end

  defmodule SuitesResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SuitesResponse",
      description: "Suites and their associated players",
      type: :object,
      properties: %{
        data: %OpenApiSpex.Schema{
          type: :object,
          additionalProperties: %OpenApiSpex.Schema{
            type: :array,
            items: %OpenApiSpex.Schema{type: :string}
          }
        }
      }
    })
  end

  defmodule ActionRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Action Parameters",
      description: "Required parameters for making an action",
      type: :object,
      properties: %{
        player_id: %Schema{type: :string, description: "Your ID"},
        game_id: %Schema{type: :string, description: "Game ID"},
        action: %Schema{type: :string, description: "Action to perform"}
      },
      required: [:player_id, :game_id, :action]
    })
  end

  defmodule StartSuiteRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Start Suite Parameters",
      description: "Required parameters for starting a new suite",
      type: :object,
      properties: %{
        players: %Schema{
          type: :array,
          items: %Schema{type: :string, description: "Player ID"},
          description: "List of player ID's"
        },
        num_games: %Schema{type: :integer, description: "Number of games to start for suite"}
      },
      required: [:players]
    })
  end

  defmodule StartSuiteResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Start Suite Response",
      description: "Response for start a new suite",
      type: :object,
      properties: %{
        suite_id: %Schema{
          type: :string,
          description: "ID of the start suite"
        }
      },
      required: [:suite_id]
    })
  end

  defmodule NotFound do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NotFound",
      type: :object,
      properties: %{
        error: %OpenApiSpex.Schema{type: :string, example: "Not found"}
      },
      required: [:error]
    })
  end

  defmodule BadRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BadRequest",
      type: :object,
      properties: %{
        error: %OpenApiSpex.Schema{type: :string, example: "Bad request"}
      },
      required: [:error]
    })
  end

  defmodule InternalServerError do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "InternalServerError",
      type: :object,
      properties: %{
        error: %OpenApiSpex.Schema{type: :string, example: "Internal server error"}
      },
      required: [:error]
    })
  end
end
