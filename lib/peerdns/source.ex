defmodule PeerDNS.Source do
  use GenServer

  require Logger

  defstruct [:file, :name, :editable, :weight, :names, :data]

  def start_link(args) do
    id = args[:id]
    if id != nil do
      Logger.info("Starting source #{args[:name]} as #{inspect id}")
      GenServer.start_link(__MODULE__, args, name: id)
    else
      GenServer.start_link(__MODULE__, args)
    end
  end

  def init(args) do
    state = %__MODULE__{
      file: args[:file],
      name: args[:name],
      editable: args[:editable] || false,
      weight: args[:weight] || 1,
      names: %{},     # name => {pk, weight}
      data: %{},      # name => PeerDNS.ZoneData
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
            %{state | names: names, data: zone_data}
          _ -> state
        end
      _ -> state
    end

    publish_names(state)
    publish_data(state)
    {:ok, state}
  end


  defp publish_names(state) do
    list = for {name, {pk, weight}} <- state.names do
      {name, pk, weight * state.weight}
    end
    PeerDNS.DB.names_update({:source, state.name}, list)
  end

  defp publish_data(state) do
    list = for {_, data} <- state.data, do: %{data | sk: nil}
    PeerDNS.DB.zone_data_update(list)
  end

  defp save(state) do
    name_list = for {name, {pk, weight}} <- state.names do
      [name, pk, weight]
    end
    zone_list = for {_, zd} <- state.data do
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
