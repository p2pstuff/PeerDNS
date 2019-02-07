defmodule PeerDNS.DB do
  use GenServer

  @expiration_time 3600*24

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def names_update(source_id, data) do
    GenServer.cast(__MODULE__, {:names_update, source_id, data})
  end

  def zone_data_update(data) do
    GenServer.cast(__MODULE__, {:zone_data_update, data})
  end

  def get_owner(name) do
    case :ets.lookup(:peerdns_names, name) do
      [{^name, pk, _, _}] -> {:ok, pk}
      _ -> {:error, :not_found}
    end
  end

  def get_zone(name) do
    case :ets.lookup(:peerdns_names, name) do
      [{^name, pk, _weight, _orig_source}] ->
        case :ets.lookup(:peerdns_zone_data, {name, pk}) do
          [{{^name, ^pk}, data}] -> {:ok, data}
          _ -> {:error, :no_data}
        end
      _ -> {:error, :not_found}
    end
  end


  # Implementation

  def init(_) do
    # The output map: {host name, public key, weight, origin source}
    :ets.new(:peerdns_names, [:set, :protected, :named_table])

    # The store map: { {name, pk}, zone_data }
    # zone_data is an instance of PeerDNS.ZoneData
    :ets.new(:peerdns_zone_data, [:set, :protected, :named_table])

    # The source data map:
    # { source_identifier, last_updated, %{name => {pk, weight}} }
    :ets.new(:peerdns_source_data, [:set, :protected, :named_table])

    {:ok, nil}
  end

  def handle_cast({:names_update, source_id, data}, state) do
    old_data = case :ets.lookup(:peerdns_source_data, source_id) do
      [{^source_id, _, d}] -> d
      [] -> %{}
    end
    k1 = MapSet.new(Map.keys(old_data))
    k2 = MapSet.new(Map.keys(data))
    changed_keys = MapSet.union(k1, k2)

    curr_time = System.os_time :second
    :ets.insert(:peerdns_source_data, {source_id, curr_time, data})

    for name <- changed_keys do
      update_name(name)
    end
    
    {:noreply, state}
  end

  def handle_cast({:zone_data_update, vals}, state) do
    for zd <- vals do
      pk = zd.pk
      case :ets.lookup(:peerdns_names, zd.name) do
        [{_, ^pk, _, _}] ->
          case :ets.lookup(:peerdns_zone_data, {zd.name, zd.pk}) do
            [{_, prev_zd}] ->
              case PeerDNS.ZoneData.update(prev_zd, zd.json, zd.signature) do
                {:ok, new_zd} ->
                  :ets.insert(:peerdns_zone_data, {{zd.name, zd.pk}, new_zd})
                _ -> nil
              end
            [] ->
              :ets.insert(:peerdns_zone_data, {{zd.name, zd.pk}, zd})
          end
        _ -> nil
      end
    end
    {:noreply, state}
  end

  defp update_name(name) do
    prev = case :ets.lookup(:peerdns_names, name) do
      [{^name, pk, _, _}] -> pk
      [] -> nil
    end
    possibilities = :ets.tab2list(:peerdns_source_data)
      |> Enum.map(fn {source, _, data} -> {source, data[name]} end)
      |> Enum.filter(fn {_, x} -> x != nil end)
      |> Enum.sort_by(fn {_, {_, w}} -> -w end)
    case possibilities do
      [] ->
        if prev != nil do
          :ets.delete(:peerdns_zone_data, {name, prev})
        end
        :ets.delete(:peerdns_names, name)
      [{source, {pk, weight}} | _] ->
        if pk != prev do
          :ets.delete(:peerdns_zone_data, {name, prev})
        end
        :ets.insert(:peerdns_names, {name, pk, weight, source})
    end
  end
end
