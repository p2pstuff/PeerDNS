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
      "privileged" => PeerDNS.is_privileged_api_ip?(conn.remote_ip)
    }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(about, pretty: true))
  end

  get "/names/pull" do
    cutoff = case Float.parse(conn.params["cutoff"] || "0") do
      {val, _} when is_number(val) and val > 0 and val <= 1 -> val
      _ -> 0
    end
    names = PeerDNS.Sync.outgoing_set(cutoff)
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(names, pretty: true))
  end

  post "/zones/pull" do
    ret = conn.params["request"]
          |> Enum.map(fn {name, pk} ->
            case :ets.lookup(:peerdns_zone_data, {name, pk}) do
              [{_, zd}] ->
                %{"pk" => zd.pk, "json" => zd.json, "signature" => zd.signature}
              [] -> nil
            end
          end)
          |> Enum.filter(&(&1 != nil))
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(ret, pretty: true))
  end

  post "/push" do
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

  forward "/privileged", to: PeerDNS.API.Privileged

  match _ do
    response = %{"result" => "error", "reason" => "not found"}
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Poison.encode!(response, pretty: true))
  end
end
