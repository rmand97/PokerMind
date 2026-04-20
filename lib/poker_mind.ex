defmodule PokerMind do
  use Boundary,
    deps: [],
    exports: [
      Engine.Match.Supervisor,
      Engine.Match.Coordinator,
      Engine.Match.Game,
      Engine.TableState,
      Engine.TableState.PlayerState,
      Engine.Poker
    ]

  @moduledoc """
  PokerMind keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
end
