defmodule PokerMind.Engine.Registry do
  def via(name) when is_binary(name) do
    {:via, Registry, {__MODULE__, name}}
  end
end
