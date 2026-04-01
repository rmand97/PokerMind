defmodule PokerMind.Engine.TableStateTest do
  alias PokerMind.Engine.TableState
  use ExUnit.Case, async: true


  setup do
    players =
      [%{name: "stine", stack_size: 100000, cards: []},
      %{name: "rolf", stack_size: 100000, cards: []},
      %{name: "asbjørn", stack_size: 100000, cards: []},
      %{name: "simon", stack_size: 100000, cards: []}]
    %{state: TableState.init(TableState.new(), players)}
  end

  test "init/2 - players, deck and player cards is initialized correct for a new table", %{state: init_state} do
    num_of_players = Enum.count(init_state.players)
    assert num_of_players == 4
  end
end
