defmodule PeerDNS.Delta do
  defstruct added: %{}, removed: []

  def calculate(old_map, new_map) do
    removed = Map.keys(old_map)
              |> Enum.filter(&(new_map[&1] == nil))
    added = new_map
            |> Enum.filter(fn {k, v} -> old_map[k] != v end)
            |> Enum.into(%{})
    %__MODULE__{added: added, removed: removed}
  end

  def is_empty?(delta) do
    delta.added == %{} and delta.removed == []
  end

  def map(delta, fun) do
    new_added = delta.added
                |> Enum.map(fn {k, v} -> {k, fun.(v)} end)
                |> Enum.into(%{})
    %{delta | added: new_added}
  end
end
