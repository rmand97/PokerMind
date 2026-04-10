defmodule PokerMind.Engine.Match.Suite do
  use Supervisor
  alias PokerMind.Engine
  alias PokerMind.Engine.Match.Coordinator
  alias PokerMind.Engine.Match.Game

  def start_link(args) do
    suite_id = Keyword.fetch!(args, :id)
    Supervisor.start_link(__MODULE__, args, name: Engine.Registry.via(suite_id))
  end

  @impl true
  def init(args) do
    suite_id = Keyword.fetch!(args, :id)
    num_games = Keyword.fetch!(args, :num_games)
    players = Keyword.fetch!(args, :players)
    coordinator_id = Coordinator.id(suite_id)

    coordinator =
      Supervisor.child_spec(
        {Coordinator, name: coordinator_id, num_games: num_games},
        id: {Coordinator, coordinator_id}
      )

    games_children =
      Enum.map(1..num_games, fn num ->
        game_id = Game.id(suite_id, num)

        Supervisor.child_spec(
          {Game, name: game_id, players: players, coordinator_id: coordinator_id},
          id: {Game, game_id}
        )
      end)

    children = [coordinator | games_children]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
