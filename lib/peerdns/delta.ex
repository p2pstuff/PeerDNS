defmodule PeerDNS.Delta do
  # Added: map name => {pk, weight}
  # Deleted: mapset name
  defstruct added: %{}, removed: %MapSet{}

  def add(addmap) do
    %__MODULE__{added: addmap}
  end

  def remove(names) do
    %__MODULE__{removed: MapSet.new(names)}
  end

  def calculate(old_map, new_map) do
    removed = Map.keys(old_map)
              |> Enum.filter(&(new_map[&1] == nil))
              |> MapSet.new()
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

  def merge(da, db) do
    added = db.added
            |> Enum.reduce(da.added, fn {k, v}, acc -> Map.put(acc, k, v) end)
            |> Enum.filter(fn {k, _} -> k not in db.removed end)
            |> Enum.into(%{})
    removed = da.removed
              |> MapSet.difference(MapSet.new(Map.keys db.added))
              |> MapSet.union(db.removed)
    %__MODULE__{added: added, removed: removed}
  end
end
