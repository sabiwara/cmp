defmodule Cmp.ComparableTest do
  use ExUnit.Case, async: true

  defmodule NotImplemented do
    defstruct [:date, :id]
  end

  defmodule ManualCompare do
    @derive {Cmp.Comparable, using: :compare}

    defstruct [:date, :id]

    def compare(left, right) do
      case Cmp.compare(left.date, right.date) do
        :eq -> Cmp.compare(left.id, right.id)
        other -> other
      end
    end
  end

  describe "implementing Cmp.Comparable using: :compare" do
    setup %{} do
      structs = [
        %ManualCompare{date: ~D[2019-06-06], id: 300},
        %ManualCompare{date: ~D[2020-03-02], id: 100},
        %ManualCompare{date: ~D[2020-03-02], id: 101}
      ]

      %{structs: structs}
    end

    test "sort/2", %{structs: structs} do
      shuffled = Enum.shuffle(structs)

      assert Cmp.sort(shuffled) == structs
    end

    test "max/1", %{structs: structs} do
      shuffled = Enum.shuffle(structs)

      assert Cmp.max(shuffled) == %ManualCompare{date: ~D[2020-03-02], id: 101}
    end

    test "min/1", %{structs: structs} do
      shuffled = Enum.shuffle(structs)

      assert Cmp.min(shuffled) == %ManualCompare{date: ~D[2019-06-06], id: 300}
    end
  end

  defmodule FieldsCompare do
    @derive {Cmp.Comparable, using: [:date, :id]}

    defstruct [:date, :id]
  end

  describe "implementing Cmp.Comparable using: fields" do
    setup %{} do
      structs = [
        %FieldsCompare{date: ~D[2019-06-06], id: 300},
        %FieldsCompare{date: ~D[2020-03-02], id: 100},
        %FieldsCompare{date: ~D[2020-03-02], id: 101}
      ]

      %{structs: structs, shuffled: Enum.shuffle(structs)}
    end

    test "sort/2", %{structs: structs, shuffled: shuffled} do
      assert Cmp.sort(shuffled) == structs
    end

    test "max/1", %{shuffled: shuffled} do
      assert Cmp.max(shuffled) == %FieldsCompare{date: ~D[2020-03-02], id: 101}
    end

    test "min/1", %{shuffled: shuffled} do
      assert Cmp.min(shuffled) == %FieldsCompare{date: ~D[2019-06-06], id: 300}
    end
  end
end
