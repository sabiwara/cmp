defmodule Cmp.Util do
  def compare_terms(left, right) when left == right, do: :eq
  def compare_terms(left, right) when left < right, do: :lt
  def compare_terms(_left, _right), do: :gt

  def comparable_structs do
    base_structs = [Date, Time, DateTime, NaiveDateTime, Version]

    if Code.ensure_loaded?(Decimal) do
      [Decimal | base_structs]
    else
      base_structs
    end
  end
end
