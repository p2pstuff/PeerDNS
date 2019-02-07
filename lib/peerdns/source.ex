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

    publish_names(state)
    publish_zones(state)
    {:ok, state}
  end

  def handle_call({:add_name, name, val}, _from, state) do
    if state.editable do
      state = %{state | names: Map.put(state.names, name, val)}
      updated(state)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:get_name, name}, _from, state) do
    case state.names[name] do
      nil -> {:reply, {:error, :not_found}, state}
      x -> {:reply, {:ok, x}, state}
    end
  end

  def handle_call({:remove_name, name}, _from, state) do
    if state.editable do
      state = %{state | names: Map.delete(state.names, name)}
      updated(state)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:add_zone, zone, weight}, _from, state) do
    if state.editable do
      state = %{state |
        names: Map.put(state.names, zone.name, {zone.pk, weight}),
        zones: Map.put(state.zones, zone.name, zone)
      }
      updated(state, true)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:get_zone, name}, _from, state) do
    case state.zones[name] do
      nil -> {:reply, {:error, :not_found}, state}
      x -> {:reply, {:ok, x}, state}
    end
  end

  def handle_call({:remove_zone, name}, _from, state) do
    if state.editable do
      state = %{state |
        names: Map.delete(state.names, name),
        zones: Map.delete(state.zones, name)
      }
      updated(state, true)
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  defp updated(state, zones \\ false) do
    save(state)
    publish_names(state)
    if zones do publish_zones(state) end
    {:reply, :ok, state}
  end

  defp publish_names(state) do
    weighted = for {name, {pk, weight}} <- state.names, into: %{} do
      {name, {pk, weight * state.weight}}
    end
    PeerDNS.DB.names_update({:source, state.name}, weighted)
  end

  defp publish_zones(state) do
    list = for {_, data} <- state.zones, do: %{data | sk: nil}
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
