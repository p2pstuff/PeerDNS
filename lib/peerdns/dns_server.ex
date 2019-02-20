defmodule PeerDNS.DNSServer do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, listen_dns} = Application.fetch_env(:peerdns, :listen_dns)
    sockets = for {ip, port} <- listen_dns do
      {:ok, addr} = :inet.parse_address(String.to_charlist ip)
      sock = case :gen_udp.open(port, [:binary, ip: addr, active: true]) do
        {:ok, sock} -> sock
        {:error, :eaddrinuse} ->
          Logger.error("Cannot bind #{ip}:#{port}, it is already used by another process.")
          exit(:error_port_already_in_use)
        {:error, :eacces} ->
          Logger.error("Cannot bind #{ip}:#{port}, you are trying to bind a privileged port as an unprivileged user.")
          Logger.error("There are ways to do that, check the readme and try again.")
          Logger.error("WARNING: running PeerDNS as root IS NOT the right solution.")
          exit(:error_privileged_port_unprivileged_user)
        err ->
          exit(err)
      end
      Logger.info("DNS server listening at #{ip}:#{port}")
      sock
    end

    {:ok, %{sockets: sockets}}
  end

  def handle_info({:udp, sock, ip, port, data}, state) do
    record = DNS.Record.decode(data)
    spawn fn ->
      response = handle(record)
      :gen_udp.send(sock, ip, port, DNS.Record.encode(response))
    end
    {:noreply, state}
  end

  def handle(record) do
    response_lol = for query <- record.qdlist do
      get_response(query)
    end

    anlist = Enum.reduce(response_lol, [], &++/2)
    rcode = case anlist do
      [] -> 3   # NXDOMAIN
      _ -> 0    # NOERROR
    end
    header = %{record.header | qr: true, rcode: rcode}
    %{record | anlist: anlist, header: header}
  end

  defp get_response(query) do
    domain = to_string(query.domain)
    [tld | rld] = domain
                  |> String.split(".")
                  |> Enum.reverse
    
    if ".#{tld}" in Application.fetch_env!(:peerdns, :tld) do
      type = case query.type do
        :a -> "A"
        :aaaa -> "AAAA"
        :txt -> "TXT"
        :cname -> "CNAME"
        :mx -> "MX"
      end

      sld = case rld do
        [sld | _] -> sld
        _ -> ""
      end
      zone = "#{sld}.#{tld}"
      case PeerDNS.DB.get_zone(zone) do
        {:ok, zd} ->
          cname_results = if query.type in [:a, :aaaa, :mx] do
            get_response(%{query | type: :cname})
          else
            []
          end

          cname_lol = for cname_res <- cname_results do
            get_response(%{query | domain: cname_res.data})
          end


          entries = Enum.filter(zd.entries, fn [d, ty | _] -> d == domain && ty == type end)
          results = for [_, _ | vals] <- entries do
            data = case {query.type, vals} do
              {xx, [ip]} when xx in [:a, :aaaa] ->
                {:ok, addr} = :inet.parse_address(String.to_charlist ip)
                addr
              {:txt, texts} ->
                texts
                |> Enum.map(&String.to_charlist/1)
              {:cname, [val]} ->
                String.to_charlist val
              {:mx, [prio, server]} ->
                {prio, String.to_charlist(server)}
            end
            %DNS.Resource{
              domain: query.domain,
              class: query.class,
              type: query.type,
              ttl: 0,
              data: data
            }
          end

          results ++ cname_results ++ Enum.reduce(cname_lol, [], &++/2)
        _ -> []
      end
    else
      resolve_outside(query)
    end
  end

  defp resolve_outside(query) do
    record = %DNS.Record{
      header: %DNS.Header{rd: true},
      qdlist: [query]
    }
    servers = Application.fetch_env!(:peerdns, :outside)
    resolve_outside(record, servers)
  end

  defp resolve_outside(_record, []), do: []
  defp resolve_outside(record, [{ip, port} | more_servers]) do
    {:ok, ip} = :inet.parse_address(String.to_charlist ip)
    {:ok, sock} = :gen_udp.open(0, [:binary])
    renc = DNS.Record.encode(record)
    :ok = :gen_udp.send(sock, ip, port, renc)
    receive do
      {:udp, ^sock, _, _, data} ->
        :gen_udp.close sock
        resp = DNS.Record.decode(data)
        resp.anlist
    after 1000 ->
      :gen_udp.close sock
      resolve_outside(record, more_servers)
    end
  end
end
