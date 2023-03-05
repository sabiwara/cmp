# Cmp

[![Hex Version](https://img.shields.io/hexpm/v/cmp.svg)](https://hex.pm/packages/cmp)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/cmp/)
[![CI](https://github.com/sabiwara/cmp/workflows/CI/badge.svg)](https://github.com/sabiwara/cmp/actions?query=workflow%3ACI)

Semantic comparison and sorting for Elixir.

## Why `Cmp`?

The built-in comparison operators as well as functions like `Enum.sort/2` or
`Enum.max/1` are based on Erlang's term ordering and suffer two issues, which
require attention and might lead to unexpected behaviors or bugs:

### 1. Structural comparisons

Built-ins use
[structural comparison over semantic comparison](https://hexdocs.pm/elixir/Kernel.html#module-structural-comparison):

```elixir
iex> ~D[2020-03-02] > ~D[2019-06-06]
false

iex> Enum.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]])
[~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]]
```

Semantic comparison is available but not straightforward:

```elixir
iex> Date.compare(~D[2019-01-01], ~D[2020-03-02])
:lt

iex> Enum.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]], Date)
[~D[2019-01-01], ~D[2019-06-06], ~D[2020-03-02]]
```

`Cmp` does the right thing out of the box:

```elixir
iex> Cmp.gt?(~D[2020-03-02], ~D[2019-06-06])
true

iex> Cmp.sort([~D[2019-01-01], ~D[2020-03-02], ~D[2019-06-06]])
[~D[2019-01-01], ~D[2019-06-06], ~D[2020-03-02]]
```

### 2. Weakly typed

Built-in comparators accept any set of operands:

```elixir
iex> 2 < "1"
true

iex> 0 < true
true

iex> false < nil
true
```

`Cmp` will only compare compatible elements or raise a `Cmp.TypeError`:

```elixir
iex> Cmp.lte?(1, 1.0)
true

iex> Cmp.lte?(2, "1")
** (Cmp.TypeError) Failed to compare incompatible types - left: 2, right: "1"
```

## Installation

`Cmp` can be installed by adding `cmp` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:cmp, "~> 0.1.0"}
  ]
end
```

The documentation can be found at
[https://hexdocs.pm/cmp](https://hexdocs.pm/cmp).

## Design goals

- Fast and well-optimized - the overhead should be quite small over built-in
  equivalents. See the `benchmarks/` folder for more details.
- No need to require macros, plain functions
- Easily extensible through the `Cmp.Comparable` protocol
- Robust and well-tested (both unit and property-based)

## Copyright and License

Cmp is licensed under the [MIT License](LICENSE.md).
