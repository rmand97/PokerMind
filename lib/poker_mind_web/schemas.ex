defmodule PokerMindWeb.Schemas do
  alias OpenApiSpex.Schema

  defmodule Card do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        rank: %Schema{
          type: :integer.
          description: "Card rank (1-13). Ace = 1, Jack = 11, Queen = 12, King = 13"}
          enum: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
        suit: %Schema{
          type: :string,
          description: "Card suit",
          enum: ["clubs", "diamonds", "hearts", "spades"]}
      },
      required: [:rank, :suit]
    })
  end

  defmodule Player do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Player ID"},
        remaining_chips: %Schema{type: :integer, description: "Remaining chips"},
        state: %Schema{
          type: :string,
          description: "Current state of the player",
          enum: ["active_in_hand", "inactive_in_hand", "all_in", "out_of_chips"]
        },
        has_acted: %Schema{
          type: :boolean,
          description: "Whether the player has acted in this betting round"
        },
        current_bet: %Schema{type: :integer, description: "Current bet this betting round"},
        total_contributed: %Schema{
          type: :integer,
          description: "Total contribution of chips this betting round"
        }
      },
      required: [:id, :remaining_chips, :state, :has_acted, :current_bet, :total_contributed]
    })
  end

  defmodule Game do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Game",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Game ID"},
        player: %Schema{
          allOf: [
            Player,
            %Schema{
              type: :object,
              properties: %{
                current_hand: %Schema{type: :array, items: Card, description: "Your hand"}
              },
              required: [:current_hand]
            }
          ]
        },
        other_players: %Schema{
          type: :array,
          items: Player,
          description: "List of other players in the game"
        },
        phase: %Schema{
          type: :string,
          description: "Current phase of the betting round",
          enum: ["pre_flop", "flop", "turn", "river", "game_finished"]
        },
        pot: %Schema{type: :integer, description: "Current size of the pot"},
        community_cards: %Schema{type: :array, items: Card, description: "Cards on the table"},
        small_blind_id: %Schema{type: :string, description: "Small blind player"},
        current_player_id: %Schema{type: :string, description: "Player to act"},
        highest_raise: %Schema{type: :integer, description: "Current bet to match"},
        big_blind_amount: %Schema{type: :integer, description: "Current big blind amount"},
        raise_amount: %Schema{type: :integer, description: "The lowest possible raise to perform"},
        winner: %Schema{
          type: :string,
          nullable: true,
          description: "The winner of the table"
        },
        hands_played: %Schema{
          type: :integer,
          description: "Number of hands currently played for this table"
        }
      },
      required: [
        :id,
        :player,
        :other_players,
        :phase,
        :pot,
        :community_cards,
        :small_blind_id,
        :current_player_id,
        :highest_raise,
        :big_blind_amount,
        :raise_amount,
        :winner,
        :hands_played
      ]
    })
  end

  defmodule GameResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GameResponse",
      description: "A list of upcoming games",
      type: :object,
      properties: %{
        all_games_finished: %Schema{
          type: :boolean,
          description: "All games in the suite are finished"
        },
        games: %Schema{
          type: :array,
          items: Game
        },
        overall_winners: %Schema{
          type: :array,
          nullable: true,
          items: %Schema{type: :string},
          description: "The overall winners of the suite"
        }
      },
      required: [:games, :all_games_finished, :overall_winners]
    })
  end

  defmodule SuitesResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SuitesResponse",
      description: "Suites and their associated players",
      type: :object,
      additionalProperties: %OpenApiSpex.Schema{
        type: :array,
        items: %OpenApiSpex.Schema{type: :string}
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
        player_id: %Schema{type: :string, description: "Player ID"},
        game_id: %Schema{type: :string, description: "Game ID"},
        action: %Schema{
          type: :string,
          description: "Action to perform",
          enum: ["fold", "check", "call", "raise", "all_in"]},
        amount: %Schema{type: :integer, description: "Required when action is raise. Provide the total amount to raise to."}
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

  defmodule CloseSuiteRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Close Suite Parameters",
      description: "Required parameters for closing a suite",
      type: :object,
      properties: %{
        suite_id: %Schema{
          type: :string,
          description: "Id of suite to close"
        }
      },
      required: [:suite_id]
    })
  end

  defmodule CloseSuiteResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Close Suite Response",
      description: "Response for closing a suite",
      type: :object,
      properties: %{}
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
