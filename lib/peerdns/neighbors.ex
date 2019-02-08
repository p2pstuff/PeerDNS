defmodule PeerDNS.Neighbors do
  use Agent

  def start_link(_) do
    static_neighbors = Application.fetch_env!(:peerdns, :static_neighbors)
                       |> Enum.map(fn opts ->
                         {:ok, ip} = :inet.parse_address(String.to_charlist(opts[:ip]))
                         {ip, Map.new(opts)}
                       end)
                       |> Enum.into(%{})
    sources = %{static: :static_neighbors}
    neighbors = static_neighbors
                |> Enum.map(fn {k, v} -> {k, Map.put(v, :source, :static)} end)
                |> Enum.into(%{})
    state = %{
      sources: sources,
      neighbors: neighbors,
    }
    Agent.start_link(fn -> state end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, &(&1.neighbors))
  end

  def get(ip) do
    Agent.get(__MODULE__, &(&1.neighbors[ip]))
  end

  def set(source_id, source_neighbors) do
    Agent.update(__MODULE__, fn state ->
      sources = Map.put(state.sources, source_id, source_neighbors)
      source_neighbors = source_neighbors
                  |> Enum.map(fn {k, v} -> {k, Map.put(v, :source, source_id)} end)
                  |> Enum.into(%{})
      neighbors = state.neighbors
                  |> Enum.filter(fn {_k, v} -> v.source != source_id end)
                  |> Map.merge(source_neighbors)
      %{sources: sources, neighbors: neighbors}
    end)
  end

end
