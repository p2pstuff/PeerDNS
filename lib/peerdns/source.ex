defmodule PeerDNS.Source do
  use GenServer

  require Logger

  defstruct [:file, :name, :editable, :weight, :names, :zones]

  def start_link(args) do
    id = args[:id]
    if id != nil do
      Logger.info("Starting source #{args[:name]} as #{inspect id}")
      GenServer.start_link(__MODULE__, args, name: id)
    else
      GenServer.start_link(__MODULE__, args)
    end
  end

  def get_all(source) do
    GenServer.call(source, :get_all)
  end

  def add_name(source, name, pk, weight) do
    GenServer.call(source, {:add_name, name, {pk, weight}})
  end

  def get_name(source, name) do
    GenServer.call(source, {:get_name, name})
  end

  def remove_name(source, name) do
    GenServer.call(source, {:remove_name, name})
  end

  def add_zone(source, zone, weight \\ 1) do
    GenServer.call(source, {:add_zone, zone, weight})
  end

  def get_zone(source, name) do
    GenServer.call(source, {:get_zone, name})
  end

  def remove_zone(source, name) do
    GenServer.call(source, {:remove_zone, name})
  end


  # Implementation

  def init(args) do
    state = %__MODULE__{
      file: args[:file],
      name: args[:name],
      editable: args[:editable] || false,
      weight: args[:weight] || 1,
      names: %{},     # name => {pk, weight}
      zones: %{},      # name => PeerDNS.ZoneData
    }

    state = case File.read(args[:file]) do
      {:ok, json} ->
        case Poison.decode(json) do
          {:ok, %{"names" => name_list, "data" => data_list}} ->
            names = for [name, pk, weight] <- name_list, into: %{} do
              {name, {pk, weight}}
            end
            zone_data = for zd <- data_list, into: %{} do
              %{"pk" => pk, "json" => json, "signature" => signature} = zd
              {:ok, zone} = PeerDNS.ZoneData.deserialize(pk, json, signature)
              {zone.name, %{zone | sk: zd["sk"]}}
            end
            %{state | names: names, zones: zone_data}
          _ -> state
        end
      _ -> state
    end

    :ok = publish_names_delta(state, %{}, state.names)
    :ok = publish_zones(state.zones)
    PeerDNS.Sync.push_delta()
    {:ok, state}
  end

  def handle_call(:get_all, _from, state) do
    {:reply, {:ok, %{names: state.names, zones: state.zones}}, state}
  end

  def handle_call({:get_name, name}, _from, state) do
    case state.names[name] do
      nil -> {:reply, {:error, :not_found}, state}
      x -> {:reply, {:ok, x}, state}
    end
  end

  def handle_call({:get_zone, name}, _from, state) do
    case state.zones[name] do
      nil -> {:reply, {:error, :not_found}, state}
      x -> {:reply, {:ok, x}, state}
    end
  end

  def handle_call({:add_name, name, val}, _from, state) do
    if state.editable do
      new_names = Map.put(state.names, name, val)
      updated(state, new_names)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:remove_name, name}, _from, state) do
    if state.editable do
      case state.zones[name] do
        nil ->
          new_names = Map.delete(state.names, name)
          updated(state, new_names)
        _ ->
          {:error, :have_zone_data}
      end
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:add_zone, zone, weight}, _from, state) do
    if state.editable do
      new_names = Map.put(state.names, zone.name, {zone.pk, weight})
      new_zones = Map.put(state.zones, zone.name, zone)
      updated(state, new_names, new_zones)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:remove_zone, name}, _from, state) do
    if state.editable do
      new_names = Map.delete(state.names, name)
      new_zones = Map.delete(state.zones, name)
      updated(state, new_names, new_zones)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  defp updated(state, new_names, new_zones \\ nil) do
    publish_names_delta(state, state.names, new_names)
    state = if new_zones do
      publish_zones(new_zones)
      %{state | names: new_names, zones: new_zones}
    else
      %{state | names: new_names}
    end
    save(state)
    PeerDNS.Sync.push_delta()
    {:reply, :ok, state}
  end

  defp publish_names_delta(state, prev_names, new_names) do
    names_delta = PeerDNS.Delta.calculate(prev_names, new_names)
    if not PeerDNS.Delta.is_empty?(names_delta) do
      names_delta = PeerDNS.Delta.map(names_delta,
        fn {pk, w} -> {pk, w * state.weight} end)
      PeerDNS.DB.handle_names_delta({:source, state.name}, names_delta)
    end
  end

  defp publish_zones(zones) do
    list = for {_, data} <- zones, do: %{data | sk: nil}
    PeerDNS.DB.zone_data_update(list)
  end

  defp save(state) do
    name_list = for {name, {pk, weight}} <- state.names do
      [name, pk, weight]
    end
    zone_list = for {_, zd} <- state.zones do
      %{
        "pk" => zd.pk,
        "sk" => zd.sk,
        "json" => zd.json,
        "signature" => zd.signature
      }
    end
    data = %{"names" => name_list, "data" => zone_list}
    json = Poison.encode!(data, pretty: true)
    File.write(state.file, json)
  end
end
