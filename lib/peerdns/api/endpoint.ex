defmodule PeerDNS.API.Endpoint do
  use Plug.Router

  plug Plug.Logger, log: :debug

  plug CORSPlug

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison

  plug :dispatch

  forward "/api", to: PeerDNS.API.Router

  get "/" do
    if File.exists?("ui/build/index.html") do
      send_file(conn, 200, "ui/build/index.html")
    else
      offsite = Application.fetch_env!(:peerdns, :offsite_ui)
      conn
      |> put_resp_header("Location", "#{offsite}?server=#{conn.host}:#{conn.port}")
      |> send_resp(301, "Moved\n")
    end
  end

  forward "/", to: Plug.Static, at: "/", from: "ui/build/"
end
