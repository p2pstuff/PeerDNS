# PeerDNS

A peer-to-peer DNS system based on a Web of Trust.

Designed to work with CJDNS, strongly inspired by
<https://docs.meshwith.me/notes/dns.html>.

## Installation

Tested on Linux, might work on other OSes as well (please tell me).  Requires
[Elixir](https://elixir-lang.org/)

PeerDNS runs a DNS server, meaning it needs to bind port 53.  You can run it as
root but it is highly discouraged!  A better solution is to allow non-root user
to bind privileged ports, or to use an alternative port and tunnel your port 53
in some way or another. 
[This page](https://stackoverflow.com/questions/413807/is-there-a-way-for-non-root-processes-to-bind-to-privileged-ports-on-linux)
contains some relevant information.

On Linux, this is an easy method to allow all users to bind ports 53 and up:

```
sudo sysctl net.ipv4.ip_unprivileged_port_start=53
```

Clone this repo and download Elixir dependencies:

```
git clone https://github.com/Alexis211/PeerDNS
cd PeerDNS
mix deps.get
```

Copy `config/config.exs.sample` to `config/config.exs` and edit to your needs.
Typically, you will want to add a few trusted peers to exchange data with. A
few are provided in the sample but you might want to use other ones.

Run PeerDNS:

```
mix run
```

