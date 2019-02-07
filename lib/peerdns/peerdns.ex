defmodule PeerDNS do
  @tld_format ~r/^\.[\d\w]+$/iu
  @zone_name_format ~r/^[\d\w_-]+\.[\d\w]+$/iu
  @full_name_format ~r/^([\d\w_-]+\.)+[\d\w]+$/iu

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
          case :inet.parse_address (String.to_charlist addr) do
            {:ok, addr} -> tuple_size(addr) == 8
            _ -> false
          end
        {"CNAME", [addr]} -> is_binary(addr)
        {"TXT", txts} -> Enum.all?(txts, &is_binary/1)
        _ -> false
      end
    end
  end

  def is_entry_valid?(_) do
    false
  end
end
