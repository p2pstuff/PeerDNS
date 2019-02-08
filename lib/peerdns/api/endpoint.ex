defmodule PeerDNS.API.Debugger do
  import Plug.Conn

  require Logger

  def init(options), do: options

  def call(conn, _opts) do
    Logger.info("PeerDNS Request Debug: #{inspect conn, pretty: true}")
    conn
  end
end

defmodule PeerDNS.API.Endpoint do
  use Plug.Router

  plug PeerDNS.API.Debugger

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison

  plug PeerDNS.API.Debugger

  plug :dispatch

  forward "/api", to: PeerDNS.API.Router

  match _ do
    send_resp(conn, 404, "Not found.\n")
  end
end
