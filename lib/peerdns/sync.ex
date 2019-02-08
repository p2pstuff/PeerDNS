defmodule PeerDNS.Sync do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def delta_pack_add_name(name, pk, weight) do
    GenServer.cast(__MODULE__, {:delta_pack_add_name, name, pk, weight})
  end

  def delta_pack_remove_name(name) do
    GenServer.cast(__MODULE__, {:delta_pack_remove_name, name})
  end

  def delta_pack_zone_change(zone_data) do
    GenServer.cast(__MODULE__, {:delta_pack_zone_change, zone_data})
  end

  def push_delta() do
    GenServer.cast(__MODULE__, :push_delta)
  end

  def outgoing_set(cutoff) do
    :ets.tab2list(:peerdns_names)
    |> Enum.filter(fn {_, _, w, _, _} -> w >= cutoff end)
    |> Enum.map(fn{name, pk, weight, ver, _source} ->
      {name, %{
        "pk" => pk,
        "weight" => weight,
        "version" => ver,
      }}
    end)
    |> Enum.into(%{})
  end

  def handle_incoming(added, removed, zones, ip) do
    {source_weight, type} = case PeerDNS.Neighbors.get(ip) do
      nil ->
        if Application.fetch_env!(:peerdns, :open) == :accept do
          {Application.fetch_env!(:peerdns, :open_weight), :open}
        else
          {0, :open}
        end
      n ->
        {n.weight, n.source}
    end
    cutoff = Application.fetch_env!(:peerdns, :cutoff)
    if source_weight < cutoff do
      {:error, :not_authorized}
    else
      try do
        added = added
                |> Enum.map(fn {name, value} ->
                  %{"weight" => w, "version" => v, "pk" => pk} = value
                  true = PeerDNS.is_zone_name_valid?(name)
                  true = PeerDNS.is_pk_valid?(pk)
                  true = is_integer(v) and v >= 0
                  true = is_number(w) and w >= 0 and w <= 1
                  {name, {pk, w * source_weight}}
                end)
                |> Enum.filter(fn {_, {_, w}} -> w >= cutoff end)
                |> Enum.into(%{})

        removed |> Enum.map(fn name -> true = PeerDNS.is_zone_name_valid? name end)

        zones = zones |> Enum.map(fn z ->
          %{"pk" => pk, "json" => json, "signature" => signature} = z
          {:ok, zd} = PeerDNS.ZoneData.deserialize(pk, json, signature)
          zd
        end)

        source_id = {type, to_string(:inet_parse.ntoa ip)}
        delta = %PeerDNS.Delta{added: added, removed: removed}
        PeerDNS.DB.handle_names_delta(source_id, delta)
        PeerDNS.DB.zone_data_update(zones)
        PeerDNS.Sync.push_delta()   # Propagate updates
        :ok
      rescue
        _ -> {:error, :invalid_input}
      end
    end
  end

  # GenServer Implementation
  
  def init(_) do
    state = %{
      name_delta: %PeerDNS.Delta{},
      zones_delta: %{},
    }
    GenServer.cast(self(), :pull)
    {:ok, state}
  end
end
