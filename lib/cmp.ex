defmodule Cmp do
  @moduledoc """
  Semantic comparison and sorting for Elixir.

  ## Why `Cmp`?

  The built-in comparison operators as well as functions like `Enum.sort/2` or `Enum.max/1`
  are based on Erlang's term ordering and suffer two issues, which require attention and
  might lead to unexpected behaviors or bugs:

  ### 1. Structural comparisons

  Built-ins use [structural comparison over semantic comparison](
    https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      ~D[2020-03-02] > ~D[2019-06-06]
      false

      iex> Enum.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]])
      [~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]]

  Semantic comparison is available but not straightforward:

      iex> Date.compare(~D[2019-01-01], ~D[2020-03-02])
      :lt

      iex> Enum.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]], Date)
      [~D[2019-01-01], ~D[2019-06-06], ~D[2020-03-02]]

  `Cmp` does the right thing out of the box:

      iex> Cmp.gt?(~D[2020-03-02], ~D[2019-06-06])
      true

      iex> Cmp.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]])
      [~D[2019-01-01], ~D[2019-06-06], ~D[2020-03-02]]

  ### 2. Weakly typed

  Built-in comparators accept any set of operands:

      iex> 2 < "1"
      true

      iex> 0 < true
      true

      iex> false < nil
      true

  `Cmp` will only compare compatible elements or raise a `Cmp.TypeError`:

      iex> Cmp.lte?(1, 1.0)
      true

      iex> Cmp.lte?(2, "1")
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 2, right: "1"

  ## What's in the box

  - Boolean comparisons: `eq?/2`, `lt?/2`, `gt?/2`, `lte?/2`, `gte?/2`
  - Equivalents of `Kernel.min/2`/ `Kernel.max/2`: `Cmp.min/2`, `Cmp.max/2`
  - Equivalents of `Enum.min/1`/ `Enum.max/1`/`Enum.sort/2`: `Cmp.min/1`, `Cmp.max/1`, `Cmp.sort/2`
  - `compare/2`

  ## Supported types

  The `Cmp.Comparable` protocol is implemented for the following types:

  - `Integer`
  - `Float`
  - `Bitstring`
  - `Date`
  - `Time`
  - `DateTime`
  - `NaiveDateTime`
  - `Version`
  - `Tuple` (see below)
  - `Decimal` (if available)

  It isn't implemented for atoms by design, since atoms are not semantically
  an ordered type.

  It supports tuples of the same size and types:

      iex> Cmp.max({12, ~D[2019-06-06]}, {12, ~D[2020-03-02]})
      {12, ~D[2020-03-02]}

      iex> Cmp.max({12, "Foo"}, {15, nil})
      ** (Cmp.TypeError) Failed to compare incompatible types - left: "Foo", right: nil

      iex> Cmp.max({12, "Foo"}, {15})
      ** (Cmp.TypeError) Failed to compare incompatible types - left: {12, "Foo"}, right: {15}

  `Decimal` support can prevent nasty bugs too:

      iex> max(Decimal.new(2), Decimal.from_float(1.0))
      #Decimal<1.0>
      iex> Cmp.max(Decimal.new(2), Decimal.from_float(1.0))
      #Decimal<2>

  See the `Cmp.Comparable` documentation to implement the protocol for other existing
  or new structs.

  ## Design goals

  - Fast and well-optimized - the overhead should be quite small over built-in equivalents.
    See the `benchmarks/` folder for more details.
  - No need to require macros, plain functions
  - Easily extensible through the `Cmp.Comparable` protocol
  - Robust and well-tested (both unit and property-based)

  Supporting comparisons between non-homogeneous types such as mixed `Decimal` and
  built-in numbers for instance is a non-goal. This limitation is a necessary
  trade-off in order to ensure the points above. Use the `Decimal` library
  directly if you need this.

  ## Limitations

  - `Cmp` comparators cannot be used in guards.
  - `Cmp` does not support (or plan to support) comparisons between non-homogeneous types
    (e.g. `Decimal` and native numbers).

  """

  alias Cmp.Comparable
  alias Cmp.Util

  @compile :inline_list_funcs

  defguardp is_base_type(value) when is_number(value) or is_binary(value)

  defguardp is_same_base_type(left, right)
            when (is_number(left) and is_number(right)) or
                   (is_binary(left) and is_binary(right))

  @doc """
  Safe equivalent to `>/2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.gt?(2, 1)
      true

      iex> Cmp.gt?(1, 2)
      false

      iex> Cmp.gt?(1, 1.0)
      false

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.gt?(1, nil)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Unlike `>/2`, it will perform a semantic comparison for structs and not a
  [structural comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      iex> Cmp.gt?(~D[2020-03-02], ~D[2019-06-06])
      true

      ~D[2020-03-02] > ~D[2019-06-06]
      false

  """
  @spec gt?(Comparable.t(), Comparable.t()) :: boolean()
  def gt?(left, right) when is_same_base_type(left, right), do: left > right
  def gt?(left, right), do: Comparable.compare(left, right) == :gt

  @doc """
  Safe equivalent to `>=/2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.gte?(2, 1)
      true

      iex> Cmp.gte?(1, 2)
      false

      iex> Cmp.gte?(1, 1.0)
      true

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.gte?(1, nil)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Unlike `>=/2`, it will perform a semantic comparison for structs and not a
  [structural comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      iex> Cmp.gte?(~D[2020-03-02], ~D[2019-06-06])
      true

      ~D[2020-03-02] >= ~D[2019-06-06]
      false

  """
  @spec gte?(Comparable.t(), Comparable.t()) :: boolean()
  def gte?(left, right) when is_same_base_type(left, right), do: left >= right
  def gte?(left, right), do: Comparable.compare(left, right) != :lt

  @doc """
  Safe equivalent to `</2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.lt?(1, 2)
      true

      iex> Cmp.lt?(2, 1)
      false

      iex> Cmp.lt?(1, 1.0)
      false

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.lt?(1, nil)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Unlike `</2`, it will perform a semantic comparison for structs and not a
  [structural comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      iex> Cmp.lt?(~D[2019-06-06], ~D[2020-03-02])
      true

      ~D[2019-06-06] < ~D[2020-03-02]
      false

  """
  @spec lt?(Comparable.t(), Comparable.t()) :: boolean()
  def lt?(left, right) when is_same_base_type(left, right), do: left < right
  def lt?(left, right), do: Comparable.compare(left, right) == :lt

  @doc """
  Safe equivalent to `<=/2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.lte?(1, 2)
      true

      iex> Cmp.lte?(2, 1)
      false

      iex> Cmp.lte?(1, 1.0)
      true

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.lte?(1, nil)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Unlike `<=/2`, it will perform a semantic comparison for structs and not a
  [structural comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      iex> Cmp.lte?(~D[2019-06-06], ~D[2020-03-02])
      true

      ~D[2019-06-06] <= ~D[2020-03-02]
      false

  """
  @spec lte?(Comparable.t(), Comparable.t()) :: boolean()
  def lte?(left, right) when is_same_base_type(left, right), do: left <= right
  def lte?(left, right), do: Comparable.compare(left, right) != :gt

  @doc """
  Safe equivalent to `==/2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.eq?(2, 1)
      false

      iex> Cmp.eq?(1, 1.0)
      true

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.eq?(1, "")
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: ""

  """
  @spec eq?(Comparable.t(), Comparable.t()) :: boolean()
  def eq?(left, right) when is_same_base_type(left, right), do: left == right
  def eq?(left, right), do: Comparable.compare(left, right) == :eq

  @doc """
  Returns `:gt` if `left` is semantically greater than `right`, `lt` if `left`
  is less than `right`, and `:eq` if they are equal.

  ## Examples

      iex> Cmp.compare(2, 1)
      :gt

      iex> Cmp.compare(1, 1.0)
      :eq

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.compare(1, "")
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: ""

  """
  @spec compare(Comparable.t(), Comparable.t()) :: :eq | :lt | :gt
  def compare(left, right) when is_same_base_type(left, right),
    do: Util.compare_terms(left, right)

  def compare(left, right), do: Comparable.compare(left, right)

  @doc """
  Safe equivalent to `max/2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.max(1, 2)
      2

      iex> Cmp.max(1, 1.0)
      1

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.max(1, nil)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Unlike `max/2`, it will perform a semantic comparison for structs and not a
  [structural comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      iex> Cmp.max(~D[2020-03-02], ~D[2019-06-06])
      ~D[2020-03-02]

      max(~D[2020-03-02], ~D[2019-06-06])
      ~D[2019-06-06]

  """
  @spec max(value, value) :: value when value: Comparable.t()
  def max(left, right) when is_same_base_type(left, right), do: Kernel.max(left, right)

  def max(left, right) do
    case Comparable.compare(left, right) do
      :lt -> right
      _ -> left
    end
  end

  @doc """
  Safe equivalent to `min/2`, which only works if both types are compatible and
  uses semantic comparison.

  ## Examples

      iex> Cmp.min(2, 1)
      1

      iex> Cmp.min(1, 1.0)
      1

  It will raise a `Cmp.TypeError` if trying to compare incompatible types

      iex> Cmp.min(1, nil)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Unlike `min/2`, it will perform a semantic comparison for structs and not a
  [structural comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

      iex> Cmp.min(~D[2020-03-02], ~D[2019-06-06])
      ~D[2019-06-06]

      min(~D[2020-03-02], ~D[2019-06-06])
      ~D[2020-03-02]

  """
  @spec min(value, value) :: value when value: Comparable.t()
  def min(left, right) when is_same_base_type(left, right), do: Kernel.min(left, right)

  def min(left, right) do
    case Comparable.compare(left, right) do
      :gt -> right
      _ -> left
    end
  end

  @doc """
  Safe equivalent of `Enum.sort/2`.

  ## Examples

      iex> Cmp.sort([3, 1, 2])
      [1, 2, 3]

      iex> Cmp.sort([3, 1, 2], :desc)
      [3, 2, 1]

  Respects semantic comparison:

      iex> Cmp.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]])
      [~D[2019-01-01], ~D[2019-06-06], ~D[2020-03-02]]

  Raises a `Cmp.TypeError` on non-uniform enumerables:

      iex> Cmp.sort([~D[2019-01-01], nil, ~D[2020-03-02]])
      ** (Cmp.TypeError) Failed to compare incompatible types - left: ~D[2019-01-01], right: nil

  """
  @spec sort(Enumerable.t(elem), :asc | :desc) :: Enumerable.t(elem) when elem: Comparable.t()
  def sort(enumerable, order \\ :asc)

  def sort([head | tail] = list, order) when is_base_type(head) do
    case order do
      :asc ->
        check_list(head, tail)
        :lists.sort(list)

      :desc ->
        [head | tail] = :lists.sort(list)
        check_reverse(head, tail, [])
    end
  end

  for struct <- Util.comparable_structs() do
    module = Module.concat(Cmp.Comparable, struct)

    def sort([%unquote(struct){} | _] = list, order) do
      gt_or_lt =
        case order do
          :asc -> :gt
          :desc -> :lt
        end

      :lists.sort(&(unquote(module).compare(&1, &2) != gt_or_lt), list)
    end
  end

  def sort([head | _] = list, order) do
    gt_or_lt =
      case order do
        :asc -> :gt
        :desc -> :lt
      end

    module = Comparable.impl_for!(head)
    :lists.sort(&(module.compare(&1, &2) != gt_or_lt), list)
  end

  def sort(list, :asc) when is_list(list) do
    :lists.sort(&lte?/2, list)
  end

  def sort(list, :desc) when is_list(list) do
    :lists.sort(&gte?/2, list)
  end

  def sort(enumerable, :asc) do
    Enum.sort(enumerable, &lte?/2)
  end

  def sort(enumerable, :desc) do
    Enum.sort(enumerable, &gte?/2)
  end

  defp check_list(_, []), do: :ok

  defp check_list(prev, [head | tail]) when is_same_base_type(prev, head) do
    check_list(head, tail)
  end

  defp check_list(prev, [head | _tail]) do
    raise Cmp.TypeError, left: prev, right: head
  end

  defp check_reverse(last, [], acc), do: [last | acc]

  defp check_reverse(prev, [head | tail], acc) when is_same_base_type(prev, head) do
    check_reverse(head, tail, [prev | acc])
  end

  defp check_reverse(prev, [head | _tail], _acc) do
    raise Cmp.TypeError, left: head, right: prev
  end

  @doc """
  Safe equivalent of `Enum.max/2`, returning the minimum of a non-empty
  enumerable of comparables.

  ## Examples

      iex> Cmp.max([1, 3, 2])
      3

  Respects semantic comparison:

      iex> Cmp.max([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]])
      ~D[2020-03-02]

  Raises a `Cmp.TypeError` on non-uniform enumerables:

      iex> Cmp.max([1, nil, 2])
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Raises an `Enum.EmptyError` on empty enumerables:

      iex> Cmp.max([])
      ** (Enum.EmptyError) empty error

  """
  @spec max(Enumerable.t(elem)) :: elem when elem: Comparable.t()
  def max(enumerable)

  def max([head | tail]) when is_number(head), do: max_list_numbers(tail, head)
  def max([head | tail]) when is_binary(head), do: max_list_binaries(tail, head)

  def max([head | _] = list) do
    module = Comparable.impl_for!(head)
    Enum.max(list, &(module.compare(&1, &2) != :lt))
  end

  def max(enumerable) do
    Enum.max(enumerable, &gte?/2)
  end

  @compile {:inline, max_list_numbers: 2, max_list_binaries: 2}

  for {fun, guard} <- [
        max_list_numbers: :is_number,
        max_list_binaries: :is_binary
      ] do
    defp unquote(fun)([], acc), do: acc

    defp unquote(fun)([head | tail], acc) when unquote(guard)(head) do
      acc =
        case head do
          new_val when new_val > acc -> new_val
          _ -> acc
        end

      unquote(fun)(tail, acc)
    end

    defp unquote(fun)([head | _tail], acc) do
      raise Cmp.TypeError, left: acc, right: head
    end
  end

  @doc """
  Safe equivalent of `Enum.min/2`, returning the maximum of a non-empty
  enumerable of comparables.

  ## Examples

      iex> Cmp.min([1, 3, 2])
      1

  Respects semantic comparison:

      iex> Cmp.min([~D[2020-03-02], ~D[2019-06-06]])
      ~D[2019-06-06]

  Raises a `Cmp.TypeError` on non-uniform enumerables:

      iex> Cmp.min([1, nil, 2])
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Raises an `Enum.EmptyError` on empty enumerables:

      iex> Cmp.min([])
      ** (Enum.EmptyError) empty error

  """
  @spec min(Enumerable.t(elem)) :: elem when elem: Comparable.t()
  def min(enumerable)

  def min([head | tail]) when is_number(head), do: min_list_numbers(tail, head)
  def min([head | tail]) when is_binary(head), do: min_list_binaries(tail, head)

  def min([head | _] = list) do
    module = Comparable.impl_for!(head)
    Enum.min(list, &(module.compare(&1, &2) != :gt))
  end

  def min(enumerable) do
    Enum.min(enumerable, &lte?/2)
  end

  @compile {:inline, min_list_numbers: 2, min_list_binaries: 2}

  for {fun, guard} <- [
        min_list_numbers: :is_number,
        min_list_binaries: :is_binary
      ] do
    defp unquote(fun)([], acc), do: acc

    defp unquote(fun)([head | tail], acc) when unquote(guard)(head) do
      acc =
        case head do
          new_val when new_val < acc -> new_val
          _ -> acc
        end

      unquote(fun)(tail, acc)
    end

    defp unquote(fun)([head | _tail], acc) do
      raise Cmp.TypeError, left: acc, right: head
    end
  end

  @doc """
  Safe equivalent of `Enum.sort_by/2`.

  ## Examples

      iex> Cmp.sort_by([%{x: 3}, %{x: 1}, %{x: 2}], & &1.x)
      [%{x: 1}, %{x: 2}, %{x: 3}]

      iex> Cmp.sort_by([%{x: 3}, %{x: 1}, %{x: 2}], & &1.x, :desc)
      [%{x: 3}, %{x: 2}, %{x: 1}]

  Respects semantic comparison:

      iex> Cmp.sort_by([%{date: ~D[2020-03-02]}, %{date: ~D[2019-06-06]}], & &1.date)
      [%{date: ~D[2019-06-06]}, %{date: ~D[2020-03-02]}]

  Raises a `Cmp.TypeError` on non-uniform enumerables:

      iex> Cmp.sort_by([%{x: 3}, %{x: "1"}, %{x: 2}], & &1.x)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 3, right: "1"

  """
  @spec sort_by(Enumerable.t(elem), (elem -> Comparable.t()), :asc | :desc) :: Enumerable.t(elem)
        when elem: term()
  def sort_by(enumerable, fun, order \\ :asc)
      when is_function(fun, 1) and order in [:asc, :desc] do
    enumerable
    |> Enum.to_list()
    |> sort_by_prepare(fun)
    |> unwrap_sort_by(order)
  end

  defp sort_by_prepare([], _fun), do: []

  defp sort_by_prepare([head | tail], fun) do
    case fun.(head) do
      val when is_number(val) ->
        sort_by_prepare_numbers(tail, fun, [{val, head}])

      val when is_binary(val) ->
        sort_by_prepare_binaries(tail, fun, [{val, head}])

      val ->
        module = Comparable.impl_for!(val)
        mapped = [{val, head} | Enum.map(tail, &{fun.(&1), &1})]
        :lists.sort(fn {left, _}, {right, _} -> module.compare(left, right) != :gt end, mapped)
    end
  end

  @compile {:inline, sort_by_prepare_numbers: 3}
  @compile {:inline, sort_by_prepare_binaries: 3}
  @compile {:inline, unwrap_sort_by_desc: 2}

  defp sort_by_prepare_numbers([], _fun, acc), do: :lists.keysort(1, acc)

  defp sort_by_prepare_numbers([head | tail], fun, acc) do
    case fun.(head) do
      val when is_number(val) ->
        sort_by_prepare_numbers(tail, fun, [{val, head} | acc])

      other ->
        [{left, _} | _] = acc
        raise Cmp.TypeError, left: left, right: other
    end
  end

  defp sort_by_prepare_binaries([], _fun, acc), do: :lists.keysort(1, acc)

  defp sort_by_prepare_binaries([head | tail], fun, acc) do
    case fun.(head) do
      val when is_binary(val) ->
        sort_by_prepare_binaries(tail, fun, [{val, head} | acc])

      other ->
        [{left, _} | _] = acc
        raise Cmp.TypeError, left: left, right: other
    end
  end

  defp unwrap_sort_by(list, :asc), do: unwrap_sort_by_asc(list)
  defp unwrap_sort_by(list, :desc), do: unwrap_sort_by_desc(list, [])

  defp unwrap_sort_by_asc([]), do: []
  defp unwrap_sort_by_asc([{_val, elem} | tail]), do: [elem | unwrap_sort_by_asc(tail)]

  defp unwrap_sort_by_desc([], acc), do: acc

  defp unwrap_sort_by_desc([{_val, elem} | tail], acc),
    do: unwrap_sort_by_desc(tail, [elem | acc])

  @doc """
  Safe equivalent of `Enum.max_by/3`, returning the element of a non-empty
  enumerable for which `fun` gives the maximum comparable value.

  ## Examples

      iex> Cmp.max_by([%{x: 1}, %{x: 3}, %{x: 2}], & &1.x)
      %{x: 3}

  Respects semantic comparison:

      iex> Cmp.max_by([%{date: ~D[2020-03-02]}, %{date: ~D[2019-06-06]}], & &1.date)
      %{date: ~D[2020-03-02]}

  Raises a `Cmp.TypeError` on non-uniform enumerables:

      iex> Cmp.max_by([%{x: 1}, %{x: nil}, %{x: 2}], & &1.x)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Raises an `Enum.EmptyError` on empty enumerables:

      iex> Cmp.max_by([], & &1.x)
      ** (Enum.EmptyError) empty error

  """
  @spec max_by(Enumerable.t(elem), (elem -> Comparable.t())) :: elem when elem: term()
  def max_by(enumerable, fun)

  def max_by([head | tail], fun) when is_function(fun, 1) do
    case fun.(head) do
      val when is_number(val) ->
        max_by_list_numbers(tail, head, val, fun)

      val when is_binary(val) ->
        max_by_list_binaries(tail, head, val, fun)

      val ->
        module = Comparable.impl_for!(val)
        max_by_list(tail, head, val, fun, module)
    end
  end

  def max_by(enumerable, fun) when is_function(fun, 1) do
    Enum.max_by(enumerable, fun, __MODULE__)
  end

  @compile {:inline, max_by_list: 5, max_by_list_numbers: 4, max_by_list_binaries: 4}

  defp max_by_list([], elem, _val, _fun, _module), do: elem

  defp max_by_list([head | tail], elem, val, fun, module) do
    new_val = fun.(head)

    case module.compare(val, new_val) do
      :lt -> max_by_list(tail, head, new_val, fun, module)
      _ -> max_by_list(tail, elem, val, fun, module)
    end
  end

  for {fun, guard} <- [
        max_by_list_numbers: :is_number,
        max_by_list_binaries: :is_binary
      ] do
    defp unquote(fun)([], elem, _val, _fun), do: elem

    defp unquote(fun)([head | tail], elem, val, fun) do
      case fun.(head) do
        other when not unquote(guard)(other) -> raise Cmp.TypeError, left: val, right: other
        new_val when new_val > val -> unquote(fun)(tail, head, new_val, fun)
        _ -> unquote(fun)(tail, elem, val, fun)
      end
    end
  end

  @doc """
  Safe equivalent of `Enum.min_by/3`, returning the element of a non-empty
  enumerable for which `fun` gives the minimum comparable value.

  ## Examples

      iex> Cmp.min_by([%{x: 1}, %{x: 3}, %{x: 2}], & &1.x)
      %{x: 1}

  Respects semantic comparison:

      iex> Cmp.min_by([%{date: ~D[2020-03-02]}, %{date: ~D[2019-06-06]}], & &1.date)
      %{date: ~D[2019-06-06]}

  Raises a `Cmp.TypeError` on non-uniform enumerables:

      iex> Cmp.min_by([%{x: 1}, %{x: nil}, %{x: 2}], & &1.x)
      ** (Cmp.TypeError) Failed to compare incompatible types - left: 1, right: nil

  Raises an `Enum.EmptyError` on empty enumerables:

      iex> Cmp.min_by([], & &1.x)
      ** (Enum.EmptyError) empty error

  """
  @spec min_by(Enumerable.t(elem), (elem -> Comparable.t())) :: elem when elem: term()
  def min_by(enumerable, fun)

  def min_by([head | tail], fun) when is_function(fun, 1) do
    case fun.(head) do
      val when is_number(val) ->
        min_by_list_numbers(tail, head, val, fun)

      val when is_binary(val) ->
        min_by_list_binaries(tail, head, val, fun)

      val ->
        module = Comparable.impl_for!(val)
        min_by_list(tail, head, val, fun, module)
    end
  end

  def min_by(enumerable, fun) when is_function(fun, 1) do
    Enum.min_by(enumerable, fun, __MODULE__)
  end

  @compile {:inline, min_by_list: 5, min_by_list_numbers: 4, min_by_list_binaries: 4}

  defp min_by_list([], elem, _val, _fun, _module), do: elem

  defp min_by_list([head | tail], elem, val, fun, module) do
    new_val = fun.(head)

    case module.compare(val, new_val) do
      :gt -> min_by_list(tail, head, new_val, fun, module)
      _ -> min_by_list(tail, elem, val, fun, module)
    end
  end

  for {fun, guard} <- [
        min_by_list_numbers: :is_number,
        min_by_list_binaries: :is_binary
      ] do
    defp unquote(fun)([], elem, _val, _fun), do: elem

    defp unquote(fun)([head | tail], elem, val, fun) do
      case fun.(head) do
        other when not unquote(guard)(other) -> raise Cmp.TypeError, left: val, right: other
        new_val when new_val < val -> unquote(fun)(tail, head, new_val, fun)
        _ -> unquote(fun)(tail, elem, val, fun)
      end
    end
  end
end
