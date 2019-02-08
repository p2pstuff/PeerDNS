defmodule PeerDNS.Sync do
  use GenServer

  require Logger

  alias PeerDNS.Delta, as: Delta

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
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
    source_weight = ip_source_weight(ip)
    cutoff = Application.fetch_env!(:peerdns, :cutoff)
    if source_weight < cutoff do
      {:error, :not_authorized}
    else
      source_id = ip_source_id(ip)
      try do
        added = added
                |> Enum.map(fn {name, value} ->
                  %{"weight" => w, "pk" => pk} = value
                  true = PeerDNS.is_zone_name_valid?(name)
                  true = PeerDNS.is_pk_valid?(pk)
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

  # GenServer Implementation
  
  def init(_) do
    Process.flag(:trap_exit, true)
    state = %{
      name_delta: %Delta{},
      zones_delta: %{},
    }
    GenServer.cast(self(), :pull)
    {:ok, state}
  end

  def handle_cast(:pull, state) do
    for {ip, args} <- PeerDNS.Neighbors.get do
      spawn_link fn -> pull_task(ip, args) end
    end
    {:noreply, state}
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
      Logger.info(data)
      for {ip, args} <- PeerDNS.Neighbors.get do
        spawn_link fn -> push_task(data, ip, args) end
      end
      state = %{ name_delta: %Delta{}, zones_delta: %{} }
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    if reason != :normal do
      Logger.info("A sync task failed:\n#{inspect reason, pretty: true}")
    end
    {:noreply, state}
  end

  defp pull_task(ip, args) do
    host = api_host(ip, args)
    Logger.info("Starting pull from #{host}...")
    cutoff = Application.fetch_env!(:peerdns, :cutoff) / args[:weight]
    data = HTTPotion.get("#{host}/api/names/pull", query: %{cutoff: cutoff})

    source_id = ip_source_id(ip)
    previous_names = :ets.match_object(:peerdns_names, {:_, :_, :_, :_, source_id})
                     |> Enum.map(&(elem(&1, 1)))
                     |> Enum.filter(&(data[&1] == nil))
    adds = data
           |> Enum.map(fn {name, data} ->
             {weight, _} = Float.parse(data["weight"])
             true = is_number(weight) and weight > 0 and weight <= 1
             true = PeerDNS.is_pk_valid?(data["pk"])
             {name, {data["pk"], weight}}
           end)
           |> Enum.into(%{})
    delta = %Delta{added: adds, removed: MapSet.new(previous_names)}
    PeerDNS.DB.handle_names_delta(source_id, delta)

    try do
      old_versions = data
                     |> Enum.map(fn {name, data} ->
                        {new_ver, _} = Integer.parse(data["version"])
                       case :ets.match(:peerdns_names, {name, data["pk"], :_, :"$1", :_}) do
                         [[old_ver]] when old_ver < new_ver-> {name, data["pk"]}
                         _ -> nil
                        end
                    end)
                    |> Enum.map(&(&1 != nil))
                    |> Enum.into(%{})
      req = Poison.encode!(%{"request" => old_versions})
      missing_zones = http_post!("#{host}/api/zones/pull", req)
      zonedata = for zd <- missing_zones do
        PeerDNS.ZoneData.deserialize(zd["pk"], zd["json"], zd["signature"])
      end
      PeerDNS.DB.zone_data_update(zonedata)
      PeerDNS.Sync.push_delta()
    rescue
      err ->
        PeerDNS.Sync.push_delta()
        raise err
    end
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

  defp push_task(data, ip, args) do
    endpoint = "#{api_host(ip, args)}/api/push"
    http_post!(endpoint, data)
  end

  defp api_host(ip, args) do
    if tuple_size(ip) == 4 do
      "http://#{:inet_parse.ntoa(ip)}:#{args.api_port}"
    else
      "http://[#{:inet_parse.ntoa(ip)}]:#{args.api_port}"
    end
  end

  defp http_post!(endpoint, data) do
    result = HTTPotion.post(endpoint, [body: data, headers: ["Content-Type": "application/json"]])
    200 = result.status_code
    "application/json" = result.headers["Content-Type"]
    result.body
  end

  defp ip_source_id(ip) do
    type = case PeerDNS.Neighbors.get(ip) do
      nil -> :open
        if Application.fetch_env!(:peerdns, :open) == :accept do
          {Application.fetch_env!(:peerdns, :open_weight), :open}
        else
          {0, :open}
        end
      n -> n.source
    end
    {type, to_string(:inet_parse.ntoa ip)}
  end

  defp ip_source_weight(ip) do
    case PeerDNS.Neighbors.get(ip) do
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
