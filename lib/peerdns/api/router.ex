defmodule PeerDNS.API.Router do
  use Plug.Router

  require Logger

  plug :match
  plug :dispatch

  get "/" do
    about = %{
      "api" => "PeerDNS",
      "server" => "PeerDNS",
      "version" => PeerDNS.MixProject.project[:version],
      "tld" => Application.fetch_env!(:peerdns, :tld),
      "operator" => Application.fetch_env!(:peerdns, :operator),
    }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(about, pretty: true))
  end

  get "/names/pull" do
    cutoff = case conn.params["cutoff"] do
      val when is_number(val) and val > 0 and val <= 1 -> val
      _ -> 0
    end
    names = PeerDNS.Sync.outgoing_set(cutoff)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(names, pretty: true))
  end

  post "/names/push" do
    %{"added" => added, "removed" => removed, "zones" => zones} = conn.body_params
    case PeerDNS.Sync.handle_incoming(added, removed, zones, conn.remote_ip) do
      :ok ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Poison.encode!(%{"result" => "success"}, pretty: true))
      {:error, reason} ->
        response = %{
          "result" => "error",
          "reason" => Atom.to_string(reason),
        }
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Poison.encode!(response, pretty: true))
    end
  end
end
