defmodule Cmp.TypeError do
  @moduledoc """
  Error raised when trying to compare values of different types.
  """

  defexception [:left, :right]

  @impl true
  def exception(left: left, right: right) do
    %__MODULE__{left: left, right: right}
  end

  @impl true
  def message(%__MODULE__{left: left, right: right}) do
    "Failed to compare incompatible types - left: #{inspect(left)}, right: #{inspect(right)}"
  end
end
