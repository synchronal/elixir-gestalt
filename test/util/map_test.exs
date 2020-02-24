defmodule Gestalt.Util.MapTest do
  use ExUnit.Case, async: true

  alias Gestalt.Util

  describe "deep_merge/2" do
    test "merges keys from the second map into the first" do
      assert Util.Map.deep_merge(%{a: 1, b: 2}, %{c: 3}) == %{a: 1, b: 2, c: 3}
    end

    test "merges nested maps" do
      assert Util.Map.deep_merge(%{a: %{c: 1}, b: 2}, %{a: %{d: 3}}) == %{a: %{c: 1, d: 3}, b: 2}
    end

    test "prefers right-most values" do
      assert Util.Map.deep_merge(%{a: 1}, %{a: 2}) == %{a: 2}
    end

    test "does not merge lists" do
      assert Util.Map.deep_merge(%{a: [b: 2]}, %{a: [c: 3]}) == %{a: [c: 3]}
    end
  end
end
