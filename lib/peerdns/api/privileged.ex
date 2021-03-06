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
    source_desc = Application.fetch_env!(:peerdns, :sources)
    sources = for {src_id, src} <- source_desc, into: %{} do
      {Atom.to_string(src_id),
        %{
          "name" => src[:name],
          "description" => src[:description],
          "editable" => src[:editable] || false,
          "weight" => src[:weight],
        }
      }
    end
    pl_desc = Application.fetch_env!(:peerdns, :peer_lists)
    peer_lists = for {pl_id, pl} <- pl_desc, into: %{} do
      {Atom.to_string(pl_id),
        %{
          "name" => pl[:name],
          "description" => pl[:description],
          "editable" => pl[:editable] || false,
          "temporary" => (pl[:file] == nil),
        }
      }
    end
    response = %{ "sources" => sources, "peer_lists" => peer_lists }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response, pretty: true))
  end

  post "/pull" do
    PeerDNS.Sync.start_full_pull()
    api_action_result(conn, :ok)
  end

  get "/neighbors" do
    neighbors = PeerDNS.Sync.get_neighbors
    statuses = PeerDNS.Sync.get_neighbor_status
    neighbors = neighbors
                |> Enum.map(fn {ip, v} ->
                  %{"ip" => "#{:inet_parse.ntoa(ip)}",
                    "name" => v.name,
                    "api_port" => v.api_port,
                    "source" => Atom.to_string(v.source),
                    "weight" => v.weight,
                    "status" => Atom.to_string(statuses[ip] || :unknown)}
                end)
                |> Enum.sort_by(&(-&1["weight"]))
    response = %{ "neighbors" => neighbors }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response, pretty: true))
  end

  get "/check" do
    name = conn.params["name"]
    response = if PeerDNS.is_full_name_valid?(name) do
      taken = case :ets.lookup(:peerdns_names, name) do
        [] -> false
        _ -> true
      end
      %{"name" => name, "valid" => true, "taken" => taken}
    else
      %{"name" => name, "valid" => false, "taken" => false}
    end
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response, pretty: true))
  end

  get "/source/:id" do
    src = check_source(id)
    id = src[:id]
    {:ok, %{names: names, zones: zones}} = PeerDNS.Source.get_all(id)
    response = %{
      "name" => src[:name],
      "description" => src[:description],
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
    src = check_source(id)
    id = src[:id]
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
    api_action_result(conn, result)
  end

  get "/peer_list/:id" do
    pl = check_peer_list(id)
    id = pl[:id]
    response = %{
      "name" => pl[:name],
      "description" => pl[:description],
      "peer_list" => PeerDNS.PeerList.get_all(id) }
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response, pretty: true))
  end

  post "/peer_list/:id" do
    pl = check_peer_list(id)
    id = pl[:id]
    result = case conn.params["action"] do
      "add" ->
        cond do
          not PeerDNS.is_ip_valid?(conn.params["ip"]) ->
            {:error, :invalid_ip}
          not is_binary(conn.params["name"]) ->
            {:error, :invalid_name}
          not (PeerDNS.is_weight_valid?(conn.params["weight"]) and conn.params["weight"] < 1.0) ->
            {:error, :invalid_weight}
          not is_integer(conn.params["api_port"]) ->
            {:error, :invalid_api_port}
          true ->
            PeerDNS.PeerList.add(id, conn.params["name"], conn.params["ip"],
              conn.params["api_port"], conn.params["weight"])
        end
      "del" ->
        cond do
          not PeerDNS.is_ip_valid?(conn.params["ip"]) ->
            {:error, :invalid_ip}
          true ->
            PeerDNS.PeerList.remove(id, conn.params["ip"])
        end
      "clear_all" ->
        PeerDNS.PeerList.clear_all(id)
      _ -> {:error, :invalid_action}
    end
    api_action_result(conn, result)
  end

  defp check_source(id) do
    s1 = Application.fetch_env!(:peerdns, :sources)[String.to_existing_atom id]
    true = (s1 != nil)
    Keyword.put(s1, :id, String.to_existing_atom id)
  end

  defp check_peer_list(id) do
    s1 = Application.fetch_env!(:peerdns, :peer_lists)[String.to_existing_atom id]
    true = (s1 != nil)
    Keyword.put(s1, :id, String.to_existing_atom id)
  end

  defp api_action_result(conn, result) do
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

  match _ do
    response = %{"result" => "error", "reason" => "not found"}
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Poison.encode!(response, pretty: true))
  end
end
