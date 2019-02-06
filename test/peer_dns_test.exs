defmodule PeerDNSTest do
  use ExUnit.Case
  doctest PeerDNS

  test "greets the world" do
    assert PeerDNS.hello() == :world
  end
end
