defmodule PeerDNS.API.Endpoint do
  use Plug.Router

  plug Plug.Logger

  plug CORSPlug

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison

  plug :dispatch

  forward "/api", to: PeerDNS.API.Router

  get "/" do
    send_file(conn, 200, "ui/build/index.html")
  end

  forward "/", to: Plug.Static, at: "/", from: "ui/build/"
end
