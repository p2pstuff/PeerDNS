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
      [{^name, sk, _, _}] -> {:ok, sk}
      _ -> {:error, :not_found}
    end
  end

  def get_zone(name) do
    case :ets.lookup(:peerdns_names, name) do
      [{^name, sk, _weight, _orig_source}] ->
        case :ets.lookup(:peerdns_data, {name, sk}) do
          [{{name, sk}, data}] -> {:ok, data}
          _ -> {:error, :no_data}
        end
      _ -> {:error, :not_found}
    end
  end


  # Implementation

  def init(_) do
    # The output map: {host name, secret key, weight, origin source}
    :ets.new(:peerdns_names, [:set, :protected])

    # The store map: { {name, sk}, zone_data }
    # zone_data is an instance of PeerDNS.ZoneData
    :ets.new(:peerdns_zone_data, [:set, :protected])

    # The source data map:
    # { source_identifier, last_updated, [ {name, sk, weight} ] }
    :ets.new(:peerdns_source_data, [:set, :protected])

    {:ok, nil}
  end
end
