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

  get "/neighbors" do
    neighbors = PeerDNS.Sync.get_neighbors
    statuses = PeerDNS.Sync.get_neighbor_status
    neighbors = neighbors
                |> Enum.map(fn {ip, v} ->
                  %{"ip" => "#{:inet_parse.ntoa(ip)}",
                    "api_port" => v.api_port,
                    "source" => Atom.to_string(v.source),
                    "weight" => v.weight,
                    "status" => Atom.to_string(statuses[ip] || :unknown)}
                end)
                |> Enum.sort_by(&(%{"up"=>0,"unknown"=>1,"down"=>2}[&1["status"]]))
    response = %{ "neighbors" => neighbors }
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
  
  post "/source/:id" do
    id = check_source(id)
    result = case conn.params["action"] do
      "add_name" ->
        cond do
          not PeerDNS.is_zone_name_valid?(conn.params["name"]) ->
            {:error, :invalid_name}
          not PeerDNS.is_pk_valid?(conn.params["pk"]) ->
            {:error, :invalid_pk}
          not PeerDNS.is_weight_valid?(conn.params["weight"]) ->
            {:error, :invalid_weight}
          true ->
            PeerDNS.Source.add_name(id, conn.params["name"],
                conn.params["pk"], conn.params["weight"])
        end
      "del_name" ->
        PeerDNS.Source.remove_name(id, conn.params["name"])
      "add_zone" ->
        cond do
          not PeerDNS.is_zone_name_valid?(conn.params["name"]) ->
            {:error, :invalid_name}
          not PeerDNS.is_weight_valid?(conn.params["weight"]) ->
            {:error, :invalid_weight}
          not (conn.params["entries"] == nil or is_list(conn.params["entries"])) ->
            {:error, :invalid_entry_list}
          not (conn.params["entries"] == nil or Enum.all?(conn.params["entries"], &PeerDNS.is_entry_valid?/1)) ->
            {:error, :invalid_entry}
          true ->
            prev_zone = case PeerDNS.Source.get_zone(id, conn.params["name"]) do
              {:ok, zd} -> zd
              _ ->
                {:ok, zd} = PeerDNS.ZoneData.new(conn.params["name"])
                zd
            end
            if conn.params["entries"] == nil do
              PeerDNS.Source.add_zone(id, prev_zone, conn.params["weight"])
            else
              {:ok, new_zone} = PeerDNS.ZoneData.set_entries(prev_zone, conn.params["entries"])
              PeerDNS.Source.add_zone(id, new_zone, conn.params["weight"])
            end
        end
      "del_zone" ->
        PeerDNS.Source.remove_zone(id, conn.params["name"])
      _ -> {:error, :invalid_action}
    end
    case result do
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
