defmodule PeerDNS.PeerList do
  use GenServer

  require Logger

  defstruct [:id, :file, :name, :editable, :data]

  def start_link(args) do
    id = args[:id]
    Logger.info("Starting peer list #{args[:name]} as #{inspect args[:id]}")
    GenServer.start_link(__MODULE__, args, name: id)
  end

  def get_all(id) do
    GenServer.call(id, :get_all)
  end

  def add(id, name, ip, api_port, weight) do
    GenServer.call(id, {:add, name, ip, api_port, weight})
  end

  def remove(id, ip) do
    GenServer.call(id, {:remove, ip})
  end

  def clear_all(id) do
    GenServer.call(id, :clear_all)
  end

  # Implementation

  def init(args) do
    default = (args[:default] || [])
              |> Enum.map(fn opts -> {opts[:ip], Map.new(opts)} end)
              |> Enum.into(%{})

    data = case args[:file] && File.read(args[:file]) do
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
          _ -> default
        end
      _ -> default
    end

    state = %__MODULE__{
      file: args[:file],
      id: args[:id],
      name: args[:name],
      editable: args[:editable] || false,
      data: data,
    }

    send_update(state)
    {:ok, state}
  end

  def handle_call(:get_all, _from, state) do
    ret = Enum.map(state.data, fn {_, v} -> v end)
    {:reply, ret, state}
  end

  def handle_call({:add, name, ip, api_port, weight}, _from, state) do
    if state.editable do
      state = %{state |
        data: Map.put(state.data, ip,
          %{name: name, ip: ip, api_port: api_port, weight: weight}
        )}
      send_update(state)
      save(state)
      {:reply, :ok, state}
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call({:remove, ip}, _from, state) do
    if state.editable do
      if state.data[ip] == nil do
        {:reply, {:error, :not_found}, state}
      else
        state = %{state | data: Map.delete(state.data, ip)}
        send_update(state)
        save(state)
        {:reply, :ok, state}
      end
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  def handle_call(clear_all, _from, state) do
    if state.editable do
      state = %{state | data: %{}}
      send_update(state)
      save(state)
      {:reply, :ok, state}
    else
      {:reply, {:error, :not_editable}, state}
    end
  end

  defp send_update(state) do
    list = state.data
           |> Enum.map(fn {ip, args} ->
             {:ok, ip} = :inet.parse_address(String.to_charlist(ip))
             %{args | ip: ip}
           end)
    PeerDNS.Sync.update_neighbors(state.id, list)
  end

  defp save(state) do
    if state.file do
      list = state.data
             |> Enum.map(fn {_, v} -> v end)
      json = Poison.encode!(list, pretty: true)
      File.write!(state.file, json)
    end
  end
end
