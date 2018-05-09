defmodule Gestalt.Util.Map do
  @moduledoc false

  def deep_merge(left, right) do
    Elixir.Map.merge(left, right, &deep_resolve/3)
  end

  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  defp deep_resolve(_key, _left, right) do
    right
  end
end