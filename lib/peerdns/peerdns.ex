defmodule PeerDNS do
  @tld_format ~r/^\.[\d\w]+$/i
  @zone_name_format ~r/^[\d\w_-]+\.[\d\w]+$/i
  @full_name_format ~r/^([\d\w_-]+\.)+[\d\w]+$/i

  def is_tld_valid?(tld) do
    Regex.match?(@tld_format, tld)
  end

  def is_zone_name_valid?(name) do
    if not Regex.match?(@zone_name_format, name) do
      false
    else
      [_, tld] = String.split(name, ".")
      ("." <> tld) in Application.fetch_env!(:peerdns, :tld)
    end
  end

  def is_full_name_valid?(name) do
    if not Regex.match?(@full_name_format, name) do
      false
    else
      [tld | _] = String.split(name, ".")
                  |> Enum.reverse
      ("." <> tld) in Application.fetch_env!(:peerdns, :tld)
    end
  end

  def is_pk_valid?(pk) do
    case Base.url_decode64(pk, padding: false) do
      {:ok, pk_bin} ->
        byte_size(pk_bin) == :enacl.sign_keypair_public_size
      _ -> false
    end
  end

  def is_entry_valid?([name, type | rest]) when is_binary(name) do
    if not is_full_name_valid?(name) do
      false
    else
      case {type, rest} do
        {"A", [addr]} when is_binary(addr) ->
          case :inet.parse_address (String.to_charlist addr) do
            {:ok, addr} -> tuple_size(addr) == 4
            _ -> false
          end
        {"AAAA", [addr]} when is_binary(addr) ->
          is_ipv6_valid?(addr)
        {"CNAME", [addr]} -> is_binary(addr)
        {"TXT", txts} -> Enum.all?(txts, &is_binary/1)
        {"MX", [prio, server]} when is_integer(prio) and is_binary(server) ->
          prio > 0
        _ -> false
      end
    end
  end

  def is_entry_valid?(_) do
    false
  end

  def is_weight_valid?(w) do
    is_number(w) and w > 0 and w <= 1
  end

  def is_privileged_api_ip?(ip) do
    cfg = Application.fetch_env!(:peerdns, :privileged_api_hosts)
    ips = for str <- cfg do
      {:ok, addr} = :inet.parse_address(String.to_charlist str)
      addr
    end
    ip in ips
  end

  def is_ip_valid?(ip) do
    case :inet.parse_address (String.to_charlist ip) do
      {:ok, _addr} -> true
      _ -> false
    end
  end

  def is_ipv6_valid?(ip) do
    case :inet.parse_address (String.to_charlist ip) do
      {:ok, addr} -> tuple_size(addr) == 8
      _ -> false
    end
  end
end
