defprotocol Cmp.Comparable do
  @moduledoc """
  A protocol to define how elements of a type can be compared.

  The simplest way to define it for a custom struct is to use @derive
  based on semantical comparison of fields, in the given order:

      defmodule MyStruct do
        @derive {Cmp.Comparable, using: [:date, :id]}

        defstruct [:id, :date]
      end

      Cmp.sort([
        %MyStruct{date: ~D[2020-03-02], id: 100},
        %MyStruct{date: ~D[2020-03-02], id: 101},
        %MyStruct{date: ~D[2019-06-06], id: 300}
      ])
      [
        %MyStruct{date: ~D[2019-06-06], id: 300},
        %MyStruct{date: ~D[2020-03-02], id: 100},
        %MyStruct{date: ~D[2020-03-02], id: 101}
      ]

  For existing structs that are already implementing a `compare/2`
  function returning `:eq | :lt | :gt`, the protocol can simply be
  done by passing `using: :compare`.

      require Protocol
      Protocol.derive(Cmp.Comparable, MyStruct, using: :compare)

  This is already done for the following modules:
  - `Date`
  - `Time`
  - `DateTime`
  - `NaiveDateTime`
  - `Version`
  - `Decimal` (if available)

  """

  # @type t :: term()
  @typedoc """
  Type of an element implementing the `Comparable` protocol.
  """

  @doc """
  Defines how to semantically compare two elements of a given type.

  This should return:
  - `:eq` if `left == right`
  - `:lt` if `left < right`
  - `:gt` if `left > right`

  """
  @spec compare(t(), t()) :: :eq | :lt | :gt
  def compare(left, right)
end

defimpl Cmp.Comparable, for: Integer do
  def compare(left, right) when is_number(right) do
    Cmp.Util.compare_terms(left, right)
  end

  def compare(left, right), do: raise(Cmp.TypeError, left: left, right: right)
end

defimpl Cmp.Comparable, for: Float do
  def compare(left, right) when is_number(right) do
    Cmp.Util.compare_terms(left, right)
  end

  def compare(left, right), do: raise(Cmp.TypeError, left: left, right: right)
end

defimpl Cmp.Comparable, for: BitString do
  def compare(left, right) when is_binary(right) do
    Cmp.Util.compare_terms(left, right)
  end

  def compare(left, right), do: raise(Cmp.TypeError, left: left, right: right)
end

defimpl Cmp.Comparable, for: Any do
  defmacro __deriving__(module, _struct, using: :compare) do
    quote do
      defimpl Cmp.Comparable, for: unquote(module) do
        @compile {:inline, compare: 2}

        def compare(left, right) when is_struct(right, unquote(module)) do
          case unquote(module).compare(left, right) do
            result when result in [:lt, :gt, :eq] -> result
          end
        end

        def compare(left, right), do: raise(Cmp.TypeError, left: left, right: right)
      end
    end
  end

  defmacro __deriving__(module, _struct, using: fields) when is_list(fields) do
    vars = Map.new([:left, :right], &{&1, Macro.var(&1, __MODULE__)})

    quote do
      defimpl Cmp.Comparable, for: unquote(module) do
        def compare(unquote(vars.left), unquote(vars.right))
            when is_struct(unquote(vars.right), unquote(module)) do
          unquote(generate_fields_comparison(fields, vars))
        end

        def compare(left, right), do: raise(Cmp.TypeError, left: left, right: right)
      end
    end
  end

  defmacro __deriving__(module, _struct, _opts) do
    raise ArgumentError, """
    Deriving Cmp.Comparable for #{inspect(module)} needs to pass a :using option which is either:

    - `using: :compare` if you plan to define a compare/2 function
    - `using: [:field1, :field2] if you want to use a list of fields

    """
  end

  def compare(left, _right) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: left
  end

  defp generate_fields_comparison([field], vars) when is_atom(field) do
    quote do
      Cmp.compare(
        Map.fetch!(unquote(vars.left), unquote(field)),
        Map.fetch!(unquote(vars.right), unquote(field))
      )
    end
  end

  defp generate_fields_comparison([field | fields], vars) when is_atom(field) do
    comparison = generate_fields_comparison([field], vars)
    continue = generate_fields_comparison(fields, vars)

    quote do
      case unquote(comparison) do
        :eq -> unquote(continue)
        result when result in [:lt, :gt] -> result
      end
    end
  end
end

for struct <- Cmp.Util.comparable_structs() do
  require Protocol
  Protocol.derive(Cmp.Comparable, struct, using: :compare)
end

defimpl Cmp.Comparable, for: Tuple do
  def compare(left, right) when is_tuple(right) and tuple_size(left) == tuple_size(right) do
    compare_tuples(left, right, 1, tuple_size(left))
  end

  def compare(left, right), do: raise(Cmp.TypeError, left: left, right: right)

  defp compare_tuples(_left, _right, i, n) when i > n, do: :eq

  defp compare_tuples(left, right, i, n) do
    l = :erlang.element(i, left)
    r = :erlang.element(i, right)

    case Cmp.compare(l, r) do
      :eq ->
        compare_tuples(left, right, i + 1, n)

      result ->
        # keep checking types even if no impact on result
        keep_checking(left, right, i + 1, n)
        result
    end
  end

  defp keep_checking(_left, _right, i, n) when i > n, do: :ok

  defp keep_checking(left, right, i, n) do
    l = :erlang.element(i, left)
    r = :erlang.element(i, right)
    Cmp.compare(l, r)
    keep_checking(left, right, i + 1, n)
  end
end
