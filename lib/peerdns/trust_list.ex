defmodule PeerDNS.TrustList do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def add(name, ip, api_port, weight) do
    GenServer.call(__MODULE__, {:add, name, ip, api_port, weight})
  end

  def remove(ip) do
    GenServer.call(__MODULE__, {:remove, ip})
  end

  # Implementation

  def init(_) do
    filename = Application.fetch_env!(:peerdns, :trust_list_file)

    data = Application.fetch_env!(:peerdns, :default_trust_list)
           |> Enum.map(fn opts ->
             {opts[:ip], Map.new(opts)}
           end)
           |> Enum.into(%{})
    data = case File.read(filename) do
      {:ok, json} ->
        case Poison.decode(json) do
          {:ok, d} when is_list d ->
            d 
            |> Enum.map(fn ent ->
              %{"ip" => ip, "api_port" => api_port,
                "name" => name, "weight" => weight} = ent
              {ip, %{ip: ip, api_port: api_port, name: name, weight: weight}}
            end)
            |> Enum.into(%{})
          _ -> data
        end
      _ -> data
    end

    state = %{
      file: filename,
      data: data,
    }
    send_update(state)
    {:ok, state}
  end

  def handle_call(:get, _from, state) do
    ret = Enum.map(state.data, fn {_, v} -> v end)
    {:reply, ret, state}
  end

  def handle_call({:add, name, ip, api_port, weight}, _from, state) do
    state = %{state | 
      data: Map.put(state.data, ip,
        %{name: name, ip: ip, api_port: api_port, weight: weight}
      )}
    send_update(state)
    save(state)
    {:reply, :ok, state}
  end

  def handle_call({:remove, ip}, _from, state) do
    if state.data[ip] == nil do
      {:reply, {:error, :not_found}, state}
    else
      state = %{state | data: Map.delete(state.data, ip)}
      send_update(state)
      save(state)
      {:reply, :ok, state}
    end
  end

  defp send_update(state) do
    list = state.data
           |> Enum.map(fn {ip, args} ->
             {:ok, ip} = :inet.parse_address(String.to_charlist(ip))
             %{args | ip: ip}
           end)
    GenServer.cast(PeerDNS.Sync, {:update_neighbors, :"Trust list", list})
  end

  defp save(state) do
    list = state.data
           |> Enum.map(fn {_, v} -> v end)
    json = Poison.encode!(list, pretty: true)
    File.write!(state.file, json)
  end
end
