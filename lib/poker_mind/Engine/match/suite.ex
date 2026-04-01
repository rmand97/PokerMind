defmodule PokerMind.Engine.Match.Suite do
  alias PokerMind.Engine
  use Supervisor

  defstruct [:id]

  def start_link(%{id: suite_id} = init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: Engine.Registry.via("S#{suite_id}"))
  end

  @impl true
  def init(%{id: suite_id} = _args) do
    coordinator =
      Supervisor.child_spec(
        {PokerMind.Engine.Match.Coordinator, name: "S#{suite_id}-Coordinator"},
        id: {PokerMind.Engine.Match.Coordinator, "S#{suite_id}-Coordinator"}
      )

    games_children =
      Enum.map(0..1, fn num ->
        Supervisor.child_spec(
          {PokerMind.Engine.Match.Game,
           name: "S#{suite_id}-G#{num}", coordinator_id: "S#{suite_id}-Coordinator"},
          id: {PokerMind.Engine.Match.Game, "S#{suite_id}-G#{num}"}
        )
      end)

    children = [coordinator | games_children]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
