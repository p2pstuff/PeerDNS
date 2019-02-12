defmodule PeerDNS.API.PrivilegeChecker do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    cfg = Application.fetch_env!(:peerdns, :privileged_api_hosts)
    ips = for str <- cfg do
      {:ok, addr} = :inet.parse_address(String.to_charlist str)
      addr
    end
    if not conn.remote_ip in ips do
      response = %{"result" => "error", "reason" => "forbidden"}
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, Poison.encode!(response, pretty: true))
      |> halt()
    else
      conn
    end
  end
end

defmodule PeerDNS.API.Privileged do
  use Plug.Router

  require Logger

  plug PeerDNS.API.PrivilegeChecker
  plug :match
  plug :dispatch

  match _ do
    response = %{"result" => "error", "reason" => "not found"}
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Poison.encode!(response, pretty: true))
  end
end
