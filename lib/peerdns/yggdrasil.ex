defmodule PeerDNS.Yggdrasil do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    params = Application.fetch_env!(:peerdns, :yggdrasil_neighbors)
    if params[:enable] do
      send(self(), :update)
      {:ok, Map.new(params)}
    else
      {:ok, nil}
    end
  end

  def handle_info(:update, state) do
    nlist = neighbors(state)
            |> Enum.filter(fn {_, args} -> args["endpoint"] != "(self)" end)
            |> Enum.map(fn {ip, args} ->
              {:ok, ip} = :inet.parse_address(String.to_charlist(ip))
              %{ip: ip, api_port: state.api_port, weight: state.weight, name: args["endpoint"]}
            end)
    PeerDNS.Sync.update_neighbors(:"Yggdrasil", nlist)
    Process.send_after(self(), :update, state.update_interval*1000)
    {:noreply, state}
  end

  # -------------------
  # Yggdrasil API calls
  
  def neighbors(params) do
    res = query(params, %{"request" => "getPeers"})
    res["response"]["peers"]
  end

  defp query(params, q) do
    sock = case params.yggdrasil_admin do
      {:local, path} ->
        {:ok, sock} = :gen_tcp.connect({:local, path}, 0, [:binary])
        sock
      {:tcp, addr, port} ->
        {:ok, ip} = :inet.parse_address(String.to_charlist addr)
        {:ok, sock} = :gen_tcp.connect(ip, port, [:binary])
        sock
    end
    :gen_tcp.send(sock, Poison.encode!(q))
    resp = read_resp(sock)
    :gen_tcp.close(sock)
    Poison.decode!(resp)
  end

  defp read_resp(sock, prev \\ "") do
    receive do
      {:tcp, ^sock, bytes} ->
        read_resp(sock, prev <> bytes)
      {:tcp_closed, ^sock} ->
        prev
    after 2000 ->
      prev
    end
  end

end
