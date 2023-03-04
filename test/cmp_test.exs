defmodule CmpTest do
  use ExUnit.Case, async: true
  doctest Cmp

  describe "edge cases" do
    test "empty on empty enums" do
      assert_raise Enum.EmptyError, fn -> Cmp.max([]) end
      assert_raise Enum.EmptyError, fn -> Cmp.min([]) end
    end

    test "undefined protocol on single lists" do
      assert_raise Protocol.UndefinedError, fn -> Cmp.max([nil]) end
      assert_raise Protocol.UndefinedError, fn -> Cmp.min([nil]) end
      assert_raise Protocol.UndefinedError, fn -> Cmp.sort([nil]) end
    end
  end
end
