defmodule PeerDNS.ZoneData do
  @derive Poison.Encoder
  defstruct [:name, :pk, :sk, :version, :entries, :json, :signature]

  def new(name) do
    if PeerDNS.is_zone_name_valid?(name) do
      %{public: pk_bin, secret: sk_bin} = :enacl.sign_keypair
      pk = Base.encode64(pk_bin, padding: false)
      sk = Base.encode64(sk_bin, padding: false)
      entries = [
        [name, "TXT", "New PeerDNS domain, no entries yet."]
      ]
      version = 1
      {:ok, json, signature} = encode_sign(sk, name, version, entries)
      zd = %__MODULE__{
        name: name,
        pk: pk,
        sk: sk,
        version: version,
        entries: entries,
        json: json,
        signature: signature
      }
      {:ok, zd}
    else
      {:error, :invalid_zone_name}
    end
  end

  def serialize(zd) do
    Poison.encode!(%{
      "pk" => zd.pk,
      "json" => zd.json,
      "signature" => zd.signature
    }, pretty: true)
  end

  def deserialize(pk, json, signature) do
    case decode_verify(pk, json, signature) do
      {:ok, name, version, entries} ->
        zd = %__MODULE__{
          name: name,
          pk: pk,
          sk: nil,
          version: version,
          entries: entries,
          json: json,
          signature: signature
        }
        if PeerDNS.is_zone_name_valid?(zd.name) do
          {:ok, zd}
        else
          {:error, :invalid_zone_name}
        end
      err -> err
    end
  end

  def deserialize(json) do
    case Poison.decode(json) do
      {:ok, %{"pk" => pk, "json" => json, "signature" => signature}} ->
        deserialize(pk, json, signature)
      _ ->
        {:error, :bad_json}
    end
  end

  def update(zd, json, signature) do
    zd_name = zd.name
    case decode_verify(zd.pk, json, signature) do
      {:ok, ^zd_name, version, entries} ->
        if version > zd.version do
          {:ok, %{zd |
            version: version,
            entries: entries,
            json: json,
            signature: signature}}
        else
          {:error, :no_update}
        end
      {:ok, _, _, _} ->
        {:error, :invalid_name}
      err -> err
    end
  end

  def entries(zd) do
    zd.entries
  end

  def set_entries(zd, entries) do
    if zd.sk == nil do
      {:error, :no_secret_key}
    else
      if Enum.all?(entries, &PeerDNS.is_entry_valid?/1) do
        version = zd.version + 1
        case encode_sign(zd.sk, zd.name, version, entries) do
          {:ok, json, signature} ->
            {:ok, %{zd |
              version: version,
              entries: entries,
              json: json,
              signature: signature}}
          err -> err
        end
      else
        {:error, :invalid_entry}
      end
    end
  end

  def add_entry(zd, entry) do
    set_entries(zd, zd.entries ++ [entry])
  end


  defp encode_sign(sk, name, version, entries) do
    case Base.decode64(sk, padding: false) do
      {:ok, sk_bin} ->
        json = Poison.encode!(%{
          "name" => name,
          "version" => version,
          "entries" => entries
        })
        signature = :enacl.sign_detached(json, sk_bin)
        {:ok, json, Base.encode64(signature, padding: false)}
      err -> err
    end
  end

  defp decode_verify(pk, json, signature) do
    case {Base.decode64(pk, padding: false), Base.decode64(signature, padding: false)} do
      {{:ok, pk_bin}, {:ok, signature_bin}} ->
        case :enacl.sign_verify_detached(signature_bin, json, pk_bin) do
          {:ok, _} ->
            case Poison.decode(json) do
              {:ok, %{"name" => name, "version" => version, "entries" => entries}} ->
                {:ok, name, version, entries}
              _ ->
                {:error, :bad_json}
            end
          _ ->
            {:error, :bad_signature}
        end
      _ -> {:error, :bad_base64}
    end
  end
end
