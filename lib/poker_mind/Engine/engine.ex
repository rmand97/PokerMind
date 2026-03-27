defmodule PokerMind.Engine do
  alias PokerMind.Engine.Match.Game

  def some_func() do
    :error
  end

  def make_move(move, %Game{} = gamestate) do
    new_player = "new_player"
    new_player2 = "new_player"

    gamestate
    |> Game.add_player(new_player)
    |> Game.add_player(new_player2)
  end
end
