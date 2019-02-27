defmodule PeerDNS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    source_desc = Application.fetch_env!(:peerdns, :sources)
    sources = for src_args <- source_desc do
      Supervisor.child_spec({PeerDNS.Source, src_args}, id: src_args[:id])
    end

    peer_list_desc = Application.fetch_env!(:peerdns, :peer_lists)
    peer_lists = for pl_args <- peer_list_desc do
      Supervisor.child_spec({PeerDNS.PeerList, pl_args}, id: pl_args[:id])
    end

    api_listen = Application.fetch_env!(:peerdns, :listen_api)
    api_processes = for {{ip, port}, i} <- Enum.with_index(api_listen) do
      id = String.to_atom "api#{i}"
      {:ok, ip} = :inet.parse_address(String.to_charlist(ip))
      Supervisor.child_spec(
        {Plug.Cowboy, scheme: :http, plug: PeerDNS.API.Endpoint,
          options: [ip: ip, port: port]},
        id: id)
    end

    children = api_processes ++ [
      PeerDNS.DB,
      PeerDNS.Sync,
      PeerDNS.DNSServer,
    ] ++ peer_lists ++ sources ++ [
      PeerDNS.CJDNS,
      PeerDNS.Yggdrasil,
    ]

    opts = [strategy: :rest_for_one, name: PeerDNS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
