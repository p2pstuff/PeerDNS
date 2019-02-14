defmodule PeerDNS.CJDNS do
  use Bitwise, only_operators: true

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    params = Application.fetch_env!(:peerdns, :cjdns_neighbors)
    send(self(), :update)
    {:ok, Map.new(params)}
  end

  def handle_info(:update, state) do
    nlist = neighbors()
            |> Enum.map(fn {ip, name} ->
              {:ok, ip} = :inet.parse_address(String.to_charlist(ip))
              %{ip: ip, api_port: state.api_port, weight: state.weight, name: name}
            end)
    PeerDNS.Sync.update_neighbors(:"CJDNS", nlist)
    Process.send_after(self(), :update, state.update_interval*1000)
    {:noreply, state}
  end

  # ---------------
  # CJDNS API calls

  def neighbors() do
    nlist = neighbors(0, [])
    for n <- nlist, n["state"] == "ESTABLISHED" do
      addr = n["addr"]
      [_, _, _, _, _, pk, _] = String.split(addr, ".")
      {:ok, pk_bin} = decode32(pk)
      hash1 = :crypto.hash(:sha512, pk_bin)
      hash2 = Base.encode16(:crypto.hash(:sha512, hash1))
      first16 = binary_part(hash2, 0, 32)
      ip = 0..7
           |> Enum.map(fn i -> binary_part(first16, i*4, 4) end)
           |> Enum.join(":")
           |> String.downcase
      {ip, n["user"]}
    end
  end

  defp neighbors(page, acc) do
    ret = PeerDNS.CJDNS.query(%{q: "InterfaceController_peerStats", args: %{page: page}})
    {:ok, %{"peers" => peerlist}} = ret
    if [] == peerlist  do
      acc
    else
      neighbors(page + 1, peerlist ++ acc)
    end
  end


  def query(q) do
    qenc = Bencode.encode!(q)

    {:ok, sock} = :gen_udp.open(0, [:binary])
    :ok = :gen_udp.send(sock, {127,0,0,1}, 11234, qenc)
    receive do
      {:udp, ^sock, _, _, resp} ->
        :gen_udp.close sock
        Bencode.decode(resp)
    after 2000 ->
        :gen_udp.close sock
        {:error, :timeout}
    end
  end

  def decode32(str) do
    decode32(str, <<>>, 0, 0)
  end

  defp decode32(input, output, nextByte, bits) do
    num_for_ascii = {
      99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,
      99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,
      99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9,99,99,99,99,99,99,
      99,99,10,11,12,99,13,14,15,99,16,17,18,19,20,99,
      21,22,23,24,25,26,27,28,29,30,31,99,99,99,99,99,
      99,99,10,11,12,99,13,14,15,99,16,17,18,19,20,99,
      21,22,23,24,25,26,27,28,29,30,31,99,99,99,99,99,
    }
    case input do
      <<>> ->
        if bits >= 5 or nextByte > 0 do
          {:error, :unfinished_input}
        else
          {:ok, output}
        end
      <<o :: 8>> <> rest_of_input ->
        if (o &&& 0x80) != 0 do
          {:error, :invalid_character}
        else
          b = elem(num_for_ascii, o)
          if b > 31 do
            {:error, :invalid_character}
          else
            nextByte = nextByte ||| (b <<< bits)
            bits = bits + 5
            if bits >= 8 do
              output = output <> <<nextByte &&& 0xFF>>
              bits = bits - 8
              nextByte = nextByte >>> 8
              decode32(rest_of_input, output, nextByte, bits)
            else
              decode32(rest_of_input, output, nextByte, bits)
            end
          end
        end
    end
  end
end
