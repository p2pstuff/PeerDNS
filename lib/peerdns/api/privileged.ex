defmodule PeerDNS.API.PrivilegeChecker do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    if not PeerDNS.is_privileged_api_ip?(conn.remote_ip) do
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

  get "/" do
    sources = for src <- Application.fetch_env!(:peerdns, :sources), into: %{} do
      {Atom.to_string(src[:id]),
        %{
          "name" => src[:name],
          "editable" => src[:editable] || false,
          "weight" => src[:weight],
        }
      }
    end
    response = %{ "sources" => sources }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response, pretty: true))
  end

  get "/source/:id" do
    id = check_source(id)
    {:ok, %{names: names, zones: zones}} = PeerDNS.Source.get_all(id)
    response = %{
      "names" => names
            |> Enum.map(fn {k, {pk, weight}} -> {k, %{"pk" => pk, "weight" => weight}} end)
            |> Enum.into(%{}),
      "zones" => zones
            |> Enum.map(fn {k, z} -> {k, %{"version" => z.version, "entries" => z.entries}} end)
            |> Enum.into(%{})
    }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response, pretty: true))
  end

  defp check_source(id) do
    [s1] = Application.fetch_env!(:peerdns, :sources)
           |> Enum.filter(&(Atom.to_string(&1[:id]) == id))
    s1[:id]
  end

  match _ do
    response = %{"result" => "error", "reason" => "not found"}
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Poison.encode!(response, pretty: true))
  end
end
