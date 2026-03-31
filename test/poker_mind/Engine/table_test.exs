defmodule PokerMind.PokerTest do
  alias PokerMind.TableState
  use ExUnit.Case, async: true

  test "init/1 - initialize game" do
    init_state = TableState.init([%{name: "stine", stack_size: 100000}])
    assert init_state.id == "123"
    assert init_state.players == [%{name: "stine", stack_size: 100000}]
    assert init_state.deck |> Enum.count() == 49
  end
end
