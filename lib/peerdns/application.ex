defmodule PeerDNS.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    source_desc = Application.fetch_env!(:peerdns, :sources)
    sources = for {src_args, i} <- Enum.with_index(source_desc, 1) do
      id = String.to_atom "source#{i}"
      src_args = [{:id, id} | src_args]
      Supervisor.child_spec({PeerDNS.Source, src_args}, id: id)
    end

    children = [
      PeerDNS.DB,
      #PeerDNS.DNSServer,
    ] ++ sources

    opts = [strategy: :one_for_one, name: PeerDNS.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
