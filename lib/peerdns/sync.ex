defmodule PeerDNS.Sync do

  def handle_incoming(list, ip) do
    {source_weight, type} = case PeerDNS.Neighbors.get(ip) do
      nil ->
        if Application.fetch_env!(:peerdns, :open) == :accept do
          {Application.fetch_env!(:peerdns, :open_weight), :open}
        else
          {0, :open}
        end
      n ->
        {n.weight, n.source}
    end
    cutoff = Application.fetch_env!(:peerdns, :cutoff)
    if source_weight < cutoff do
      {:error, :not_authorized}
    else
      try do
        list
        |> Enum.map(fn {name, %{"weight" => w, "version" => v, "pk" => pk}} ->
          true = PeerDNS.is_zone_name_valid?(name)
          true = PeerDNS.is_pk_valid?(pk)
          true = is_integer(v) and v >= 0
          true = is_number(w) and w >= 0 and w <= 1
          {type, {pk, w * source_weight}}
        end)
        |> Enum.filter(fn {_, {_, w}} -> w >= cutoff end)
        |> Enum.into(%{})
        PeerDNS.DB.names_update({type, to_string(:inet_parse.ntoa ip)}, list)
        :ok
      rescue
        _ -> {:error, :invalid_input}
      end
    end
  end
end
