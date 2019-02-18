defmodule PeerDNS.Sync do
  use GenServer

  require Logger

  alias PeerDNS.Delta, as: Delta

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get_neighbors() do
    GenServer.call(__MODULE__, :get_neighbors)
  end

  def get_neighbor_status() do
    GenServer.call(__MODULE__, :get_neighbor_status)
  end

  def update_neighbors(nsource, nlist) do
    GenServer.cast(__MODULE__, {:update_neighbors, nsource, nlist})
  end

  def delta_pack_add_name(name, pk, weight) do
    Logger.info("Packing delta: add or modify name #{name} => #{pk}, #{weight}")
    GenServer.cast(__MODULE__, {:delta_pack_add_name, name, pk, weight})
  end

  def delta_pack_remove_name(name) do
    Logger.info("Packing delta: remove name #{name}")
    GenServer.cast(__MODULE__, {:delta_pack_remove_name, name})
  end

  def delta_pack_zone_change(zone_data) do
    Logger.info("Packing delta: zone #{zone_data.name} version #{zone_data.version}")
    GenServer.cast(__MODULE__, {:delta_pack_zone_change, zone_data})
  end

  def push_delta() do
    GenServer.cast(__MODULE__, :push_delta)
  end

  def outgoing_set(cutoff) do
    :ets.tab2list(:peerdns_names)
    |> Enum.filter(fn {_n, _k, w, _v, _s, _t} -> w >= cutoff end)
    |> Enum.map(fn{name, pk, weight, ver, _source, _time} ->
      {name, %{
        "pk" => pk,
        "weight" => weight,
        "version" => ver,
      }}
    end)
    |> Enum.into(%{})
  end

  def handle_incoming(added, removed, zones, ip) do
    info = PeerDNS.Sync.get_neighbors()[ip]
    source_weight = ip_source_weight(info)
    cutoff = Application.fetch_env!(:peerdns, :cutoff)
    if source_weight < cutoff do
      {:error, :not_authorized}
    else
      source_id = ip_source_id(ip, info)
      try do
        added = added
                |> Enum.filter(fn {name, _} ->
                  PeerDNS.is_zone_name_valid? name
                end)
                |> Enum.map(fn {name, value} ->
                  %{"weight" => w, "pk" => pk} = value
                  true = PeerDNS.is_zone_name_valid?(name)
                  true = PeerDNS.is_pk_valid?(pk)
                  true = is_number(w) and w > 0 and w <= 1
                  {name, {pk, w * source_weight}}
                end)
                |> Enum.filter(fn {_, {_, w}} -> w >= cutoff end)
                |> Enum.into(%{})

        removed = Enum.filter(removed, &(PeerDNS.is_zone_name_valid?(&1)))

        zones = zones
                |> Enum.map(fn z ->
                  %{"pk" => pk, "json" => json, "signature" => signature} = z
                  case PeerDNS.ZoneData.deserialize(pk, json, signature) do
                    {:ok, zd} -> zd
                    _ -> nil
                  end
                end)
                |> Enum.filter(&(&1 != nil))

        delta = %Delta{added: added, removed: MapSet.new(removed)}
        PeerDNS.DB.handle_names_delta(source_id, delta)
        PeerDNS.DB.zone_data_update(zones)
        PeerDNS.Sync.push_delta()   # Propagate updates
        :ok
      rescue
        _ -> {:error, :invalid_input}
      end
    end
  end


  # -----------------------------------------
  # GenServer Implementation
  
  def init(_) do
    state = %{
      name_delta: %Delta{},
      zones_delta: %{},
      neighbor_sources: %{},
      neighbors: %{},
      neighbor_status: %{},
    }

    for pp <- Application.fetch_env!(:peerdns, :pull_policy) do
      dt = pp[:interval] * 1000
      Process.send_after(self(), {:pull, pp[:cutoff], pp[:interval]}, dt)
    end

    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  def handle_call(:get_neighbors, _from, state) do
    {:reply, state.neighbors, state}
  end

  def handle_call(:get_neighbor_status, _from, state) do
    {:reply, state.neighbor_status, state}
  end

  def handle_cast({:neighbor_status, ip, status}, state) do
    if state.neighbor_status[ip] != status do
      Logger.info("Neighbor status #{:inet_parse.ntoa(ip)}: #{inspect status}")
    end
    state = %{state | neighbor_status: Map.put(state.neighbor_status, ip, status)}
    {:noreply, state}
  end

  def handle_cast({:update_neighbors, source_id, source_neighbors}, state) do
    sources = Map.put(state.neighbor_sources, source_id, source_neighbors)
    neighbors = sources
                |> Enum.map(fn {source_id, neighs} ->
                  Enum.map(neighs, fn v -> Map.put(v, :source, source_id) end)
                end)
                |> Enum.reduce([], &++/2)
                |> Enum.reduce(%{}, fn neigh, acc ->
                  if acc[neigh.ip] == nil or neigh.weight > acc[neigh.ip].weight do
                    Map.put(acc, neigh.ip, neigh)
                  else
                    acc
                  end
                end)
    # Launch a pull for new neighbors
    cutoff = Application.fetch_env!(:peerdns, :cutoff)
    for {ip, args} <- neighbors do
      if state.neighbors[ip] == nil do
        spawn_link fn -> pull_task(args, cutoff) end
      end
    end
    {:noreply, %{state | neighbor_sources: sources, neighbors: neighbors}}
  end

  def handle_cast({:delta_pack_add_name, name, pk, weight}, state) do
    delta = Delta.add(%{name => {pk, weight}})
    state = %{state | name_delta: Delta.merge(state.name_delta, delta)}
    {:noreply, state}
  end

  def handle_cast({:delta_pack_remove_name, name}, state) do
    delta = Delta.remove([name])
    state = %{state | name_delta: Delta.merge(state.name_delta, delta)}
    {:noreply, state}
  end

  def handle_cast({:delta_pack_zone_change, zd}, state) do
    state = %{state | zones_delta: Map.put(state.zones_delta, zd.name, zd)}
    {:noreply, state}
  end

  def handle_cast(:push_delta, state) do
    nadd = map_size state.name_delta.added
    ndel = MapSet.size state.name_delta.removed
    nzone = map_size state.zones_delta
    if nadd + ndel + nzone > 0 do
      Logger.info("Pushing delta: #{nadd} new or modified names, #{ndel} deleted names, #{nzone} new or modified zones")
      data = push_data(state)
      for {_, args} <- state.neighbors do
        spawn_link fn -> push_task(args, data) end
      end
      state = %{ state | name_delta: %Delta{}, zones_delta: %{} }
      {:noreply, state}
    else
      {:noreply, state}
    end
  end
  
  def handle_info({:pull, cutoff, interval}, state) do
    Logger.info("Launching pulls with cutoff #{cutoff} (interval #{interval}s)")
    for {_, args} <- state.neighbors do
      spawn_link fn -> pull_task(args, cutoff) end
    end
    Process.send_after(self(), {:pull, cutoff, interval}, interval*1000)
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    if reason != :normal do
      Logger.info("A sync task failed: #{inspect reason}.")
    end
    {:noreply, state}
  end

  defp pull_task(args, cutoff) do
    source_weight = ip_source_weight(args)
    source_id = ip_source_id(args.ip, args)

    Logger.info("Starting pull from #{:inet.ntoa(args.ip)} with cutoff #{cutoff}...")
    q_cutoff = cutoff / source_weight
    data = http_get!(args, "/api/names/pull", %{cutoff: to_string q_cutoff})
    data = Poison.decode!(data)

    # Ignore data for TLDs we don't care about
    data = Map.drop(data, Enum.filter(Map.keys(data), &(not PeerDNS.is_zone_name_valid?(&1))))

    sel_previous_names = [{ {:'$1', :_, :'$2', :_, source_id, :_},
                            [ {:>=, :'$2', cutoff} ],
                            [ :'$1' ] }]
    previous_names = :ets.match_object(:peerdns_names, sel_previous_names)
                     |> Enum.map(fn [name] -> name end)
                     |> Enum.filter(&(data[&1] == nil))
    adds = data
           |> Enum.map(fn {name, val} ->
             %{"weight" => weight, "pk" => pk} = val
             true = is_number(weight) and weight > 0 and weight <= 1
             true = PeerDNS.is_pk_valid?(val["pk"])
             {name, {pk, source_weight * weight}}
           end)
           |> Enum.filter(fn {_, {_, w}} -> w >= cutoff end)
           |> Enum.into(%{})
    delta = %Delta{added: adds, removed: MapSet.new(previous_names)}
    PeerDNS.DB.handle_names_delta(source_id, delta)

    old_versions = data
                   |> Enum.map(fn {name, data} ->
                     new_ver = data["version"]
                     true = is_integer new_ver
                     case :ets.match(:peerdns_names, {name, data["pk"], :_, :"$1", :_, :_}) do
                       [[old_ver]] when old_ver < new_ver-> {name, data["pk"]}
                       _ -> nil
                     end
                   end)
                   |> Enum.filter(&(&1 != nil))
                   |> Enum.into(%{})
    req = Poison.encode!(%{"request" => old_versions})
    missing_zones = http_post!(args, "/api/zones/pull", req)
    zonedata = for zd <- Poison.decode!(missing_zones) do
      {:ok, zd} = PeerDNS.ZoneData.deserialize(zd["pk"], zd["json"], zd["signature"])
      zd
    end
    PeerDNS.DB.zone_data_update(zonedata)
    PeerDNS.Sync.push_delta()
  end

  defp push_data(state) do
    added_dict = state.name_delta.added
                 |> Enum.map(fn {name, {pk, w}} ->
                   {name, %{"pk" => pk, "weight" => w}}
                 end)
                 |> Enum.into(%{})
    zone_list = state.zones_delta
                |> Enum.map(fn {_, zd} ->
                  %{"pk" => zd.pk, "json" => zd.json, "signature" => zd.signature}
                end)
    dict = %{
      "added" => added_dict,
      "removed" => Enum.to_list(state.name_delta.removed),
      "zones" => zone_list
    }
    Poison.encode!(dict, pretty: true)
  end

  defp push_task(args, data) do
    http_post!(args, "/api/push", data)
  end

  defp api_host(args) do
    if tuple_size(args.ip) == 4 do
      "http://#{:inet_parse.ntoa(args.ip)}:#{args.api_port}"
    else
      "http://[#{:inet_parse.ntoa(args.ip)}]:#{args.api_port}"
    end
  end

  defp http_get!(args, endpoint, query \\ nil) do
    host = api_host(args)
    result = case HTTPotion.get(host <> endpoint,
      [query: query, ibrowse: [host_header: "peerdns"]])
    do
      %HTTPotion.ErrorResponse{} ->
        GenServer.cast(__MODULE__, {:neighbor_status, args.ip, :down})
        exit :normal
      r ->
        GenServer.cast(__MODULE__, {:neighbor_status, args.ip, :up})
        r
    end
    200 = result.status_code
    "application/json" <> _ = result.headers["Content-Type"]
    result.body
  end

  defp http_post!(args, endpoint, data) do
    host = api_host(args)
    result = case HTTPotion.post(host <> endpoint,
      [body: data,
        headers: ["Content-Type": "application/json"],
        ibrowse: [host_header: "peerdns"]])
    do
      %HTTPotion.ErrorResponse{} ->
        GenServer.cast(__MODULE__, {:neighbor_status, args.ip, :down})
        exit :normal
      r ->
        GenServer.cast(__MODULE__, {:neighbor_status, args.ip, :up})
        r
    end
    200 = result.status_code
    "application/json" <> _ = result.headers["Content-Type"]
    result.body
  end

  defp ip_source_id(ip, info) do
    type = case info do
      nil -> :open
      n -> n.source
    end
    {type, to_string(:inet_parse.ntoa ip)}
  end

  defp ip_source_weight(info) do
    case info do
      nil ->
        if Application.fetch_env!(:peerdns, :open) == :accept do
          Application.fetch_env!(:peerdns, :open_weight)
        else
          0
        end
      n -> n.weight
    end
  end
end
