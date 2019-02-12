defmodule PeerDNS.API.Endpoint do
  use Plug.Router

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison

  plug :dispatch

  forward "/api", to: PeerDNS.API.Router

  match _ do
    send_resp(conn, 404, "Not found.\n")
  end
end
