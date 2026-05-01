defmodule PokerMind.Engine.Registry do
  def via(name, type) when is_binary(name) and is_atom(type) do
    {:via, Registry, {__MODULE__, name, type}}
  end
end
