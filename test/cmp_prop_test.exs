defmodule Cmp.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag timeout: :infinity
  @moduletag :property

  def log_rescale(generator) do
    scale(generator, &trunc(:math.log(&1)))
  end

  def number(), do: one_of([integer(), float()])

  def date() do
    map({integer(0..3000), integer(1..365)}, fn {y, d} ->
      Date.new!(y, 1, 1) |> Date.add(d - 1)
    end)
  end

  @seconds 24 * 3600

  def time() do
    map(integer(1..@seconds), &Time.from_seconds_after_midnight(&1 - 1))
  end

  defp types, do: [number(), binary(), date(), time(), {number(), binary()}, {date(), time()}]

  def pair() do
    types()
    |> Enum.map(&{&1, &1})
    |> one_of()
  end

  describe "consistency with Enum" do
    property "list of numbers" do
      check all(list <- list_of(number(), min_length: 1)) do
        assert Cmp.max(list) == Enum.max(list)
        assert Cmp.min(list) == Enum.min(list)
        assert Cmp.sort(list) == Enum.sort(list)
        assert Cmp.sort(list, :asc) == Enum.sort(list, :asc)
        assert Cmp.sort(list, :desc) == Enum.sort(list, :desc)
      end
    end

    property "list of binaries" do
      check all(list <- list_of(binary(), min_length: 1)) do
        assert Cmp.max(list) == Enum.max(list)
        assert Cmp.min(list) == Enum.min(list)
        assert Cmp.sort(list) == Enum.sort(list)
        assert Cmp.sort(list, :asc) == Enum.sort(list, :asc)
        assert Cmp.sort(list, :desc) == Enum.sort(list, :desc)
      end
    end

    property "list of tuples of numbers" do
      check all(list <- list_of({number(), number()}, min_length: 1)) do
        assert Cmp.max(list) == Enum.max(list)
        assert Cmp.min(list) == Enum.min(list)
        assert Cmp.sort(list) == Enum.sort(list)
        assert Cmp.sort(list, :asc) == Enum.sort(list, :asc)
        assert Cmp.sort(list, :desc) == Enum.sort(list, :desc)
      end
    end

    property "list of dates" do
      check all(list <- list_of(date(), min_length: 1)) do
        assert Cmp.max(list) == Enum.max(list, Date)
        assert Cmp.min(list) == Enum.min(list, Date)
        assert Cmp.sort(list) == Enum.sort(list, Date)
        assert Cmp.sort(list, :asc) == Enum.sort(list, Date)
        assert Cmp.sort(list, :desc) == Enum.sort(list, {:desc, Date})
      end
    end

    property "list of times" do
      check all(list <- list_of(time(), min_length: 1)) do
        assert Cmp.max(list) == Enum.max(list, Time)
        assert Cmp.min(list) == Enum.min(list, Time)
        assert Cmp.sort(list) == Enum.sort(list, Time)
        assert Cmp.sort(list, :asc) == Enum.sort(list, Time)
        assert Cmp.sort(list, :desc) == Enum.sort(list, {:desc, Time})
      end
    end

    defmodule DateTimeTuple do
      def compare({d1, t1}, {d2, t2}) do
        dt1 = DateTime.new!(d1, t1)
        dt2 = DateTime.new!(d2, t2)
        DateTime.compare(dt1, dt2)
      end
    end

    property "list of tuples of dates and time" do
      check all(list <- list_of({date(), time()}, min_length: 1)) do
        assert Cmp.max(list) == Enum.max(list, DateTimeTuple)
        assert Cmp.min(list) == Enum.min(list, DateTimeTuple)
        assert Cmp.sort(list) == Enum.sort(list, DateTimeTuple)
        assert Cmp.sort(list, :asc) == Enum.sort(list, DateTimeTuple)
        assert Cmp.sort(list, :desc) == Enum.sort(list, {:desc, DateTimeTuple})
      end
    end
  end

  describe "binary comparisons" do
    property "boolean invariants" do
      check all({left, right} <- pair()) do
        assert Cmp.gt?(left, right) == not Cmp.lte?(left, right)
        assert Cmp.lt?(left, right) == not Cmp.gte?(left, right)
        assert (Cmp.lte?(left, right) and Cmp.gte?(left, right)) == Cmp.eq?(left, right)
        assert Cmp.lte?(left, right) == Cmp.lt?(left, right) or Cmp.eq?(left, right)
        assert Cmp.gte?(left, right) == Cmp.gt?(left, right) or Cmp.eq?(left, right)

        assert Cmp.eq?(left, right) == (left == right)
      end
    end

    property "min and max" do
      check all({left, right} <- pair()) do
        [min, max] = Cmp.sort([left, right])
        assert Cmp.min(left, right) == min
        assert Cmp.max(left, right) == max
        assert Cmp.lte?(min, max) == true
        assert Cmp.gte?(max, min) == true
      end
    end

    property "compare consistency" do
      check all({left, right} <- pair()) do
        result = Cmp.compare(left, right)
        assert Cmp.eq?(left, right) == (result == :eq)
        assert Cmp.gt?(left, right) == (result == :gt)
        assert Cmp.lt?(left, right) == (result == :lt)

        assert Cmp.compare({left}, {right}) == result
        assert Cmp.compare({left, left}, {right, right}) == result
        assert Cmp.compare({left, 0}, {right, 0.0}) == result
      end
    end
  end

  describe "incompatible type guards" do
    property "list with a nil" do
      check all([head | tail] <- types() |> one_of() |> list_of(min_length: 1)) do
        list = [head] ++ Enum.shuffle([nil] ++ tail)

        assert_raise Cmp.TypeError, fn -> Cmp.max(list) end
        assert_raise Cmp.TypeError, fn -> Cmp.min(list) end
        assert_raise Cmp.TypeError, fn -> Cmp.sort(list) end
        assert_raise Cmp.TypeError, fn -> Cmp.sort(list, :asc) end
        assert_raise Cmp.TypeError, fn -> Cmp.sort(list, :desc) end
      end
    end

    property "list with a different struct" do
      check all([head | tail] <- types() |> one_of() |> list_of(min_length: 1)) do
        list = [head] ++ Enum.shuffle([DateTime.utc_now()] ++ tail)

        assert_raise Cmp.TypeError, fn -> Cmp.max(list) end
        assert_raise Cmp.TypeError, fn -> Cmp.min(list) end
        assert_raise Cmp.TypeError, fn -> Cmp.sort(list) end
        assert_raise Cmp.TypeError, fn -> Cmp.sort(list, :asc) end
        assert_raise Cmp.TypeError, fn -> Cmp.sort(list, :desc) end
      end
    end

    property "binary comparisons with nil (right)" do
      check all(elem <- types() |> one_of()) do
        assert_raise Cmp.TypeError, fn -> Cmp.compare(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.gt?(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.gte?(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.lt?(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.lte?(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.eq?(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.max(elem, nil) end
        assert_raise Cmp.TypeError, fn -> Cmp.min(elem, nil) end
      end
    end

    property "binary comparisons with nil (left)" do
      check all(elem <- types() |> one_of()) do
        assert_raise Protocol.UndefinedError, fn -> Cmp.compare(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.gt?(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.gte?(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.lt?(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.lte?(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.eq?(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.max(nil, elem) end
        assert_raise Protocol.UndefinedError, fn -> Cmp.min(nil, elem) end
      end
    end
  end
end
