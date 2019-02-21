defmodule PeerDNS.DNSServer do
  use GenServer

  require Logger

  defmodule Response do
    def success(query, anlist) do
      header = %{query.header | qr: true, rcode: 0}
      %{query | anlist: anlist, header: header}
    end

    def error(query, code) do
      rcode = case code do
        :servfail -> 2
        :nxdomain -> 3
        :notimp -> 4
      end
      header = %{query.header | qr: true, rcode: rcode}
      %{query | header: header}
    end

    def rand(r1, r2) do
      cond do
        r1.header.rcode != 0 -> r1
        r2.header.rcode != 0 -> r2
        true ->
          %{r1 | anlist: r1.anlist ++ r2.anlist}
      end
    end

    def ror(r1, r2) do
      cond do
        r2.header.rcode != 0 -> r1
        r1.header.rcode != 0 -> r2
        true ->
          %{r1 | anlist: r1.anlist ++ r2.anlist}
      end
    end

    def randmaybe(r1, r2) do
      cond do
        r1.header.rcode != 0 -> r1
        r2.header.rcode != 0 -> r1
        true ->
          %{r1 | anlist: r1.anlist ++ r2.anlist}
      end
    end
  end

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
      get_response(record, query)
    end

    Enum.reduce(response_lol, Response.success(record, []), &Response.rand/2)
  end

  defp get_response(qrecord, query) do
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
            get_response(qrecord, %{query | type: :cname})
          else
            Response.success(qrecord, [])
          end

          cname_lol = for cname_res <- cname_results.anlist do
            get_response(qrecord, %{query | domain: cname_res.data})
          end

          entries = Enum.filter(zd.entries, fn [d, ty | _] -> d == domain && ty == type end)
          result_entries = for [_, _ | vals] <- entries do
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
          results = case result_entries do
            [] -> Response.error(qrecord, :nxdomain)
            _ -> Response.success(qrecord, result_entries)
          end

          Response.ror(
            results,
            Response.rand(cname_results,
              Enum.reduce(cname_lol,
                Response.error(qrecord, :nxdomain),
                &Response.ror/2)))
        _ -> Response.error(qrecord, :nxdomain)
      end
    else
      resolve_outside(%{qrecord | qdlist: [query]})
    end
  end

  defp resolve_outside(record) do
    servers = Application.fetch_env!(:peerdns, :outside)
    resolve_outside(record, servers)
  end

  defp resolve_outside(record, []) do
    Response.error(record, :servfail)
  end

  defp resolve_outside(record, [{ip, port} | more_servers]) do
    {:ok, ip} = :inet.parse_address(String.to_charlist ip)
    {:ok, sock} = :gen_udp.open(0, [:binary])
    renc = DNS.Record.encode(record)
    :gen_udp.send(sock, ip, port, renc)
    receive do
      {:udp, ^sock, _, _, data} ->
        :gen_udp.close sock
        DNS.Record.decode(data)
    after 1000 ->
      :gen_udp.close sock
      resolve_outside(record, more_servers)
    end
  end
end
