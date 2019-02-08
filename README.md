# PeerDNS

A peer-to-peer DNS system based on a Web of Trust.

Designed to work with CJDNS, strongly inspired by
<https://docs.meshwith.me/notes/dns.html>.


## How it works

Each peer has a list of domains it knows about and their "weight", i.e. their
trust value between 0 and 1.  If a peer know about several conflicting versions
of a domain, the one with the highest weight wins.

A peer may publish its own domain list. It will usually set their weight to 1
in this case.  A peer can also pull the domain list of other peers, in which
case it will scale all the weights announced by that peer by a factor
corresponding to the trust given to the peer.  For example if I pull a domain
that a certain peer announce with weight `0.5`, and I have decided to trust
that peer with a weight `0.8`, then I will consider that domain with a weight
`0.5 * 0.8 = 0.4`.

Typically a node will peer with a few highly trusted nodes with a weight of
`0.8` or `0.9`.  If running on a CJDNS Mesh network, it can also peer
automatically with its immediate CJDNS neighbors, in which case a default
weight of for instance `0.5` can be given to any neighbor.  Then it can
optionnally accept domains from anyone with a very low weight, say `0.1`.

For a new peer to join the network and announce a new domain, there are several
options:

- The peer can simply announce its domains to open peers, in which case they
  will be given a very low weight.
- The owner of the peer can ask some higly trusted peers to add their peer to
  their trust list with a higher weight.
- Thirdly, PeerDNS has an announce mechanism such that if a peer announces its
  presence and domain names sufficiently frequently and for a sufficiently long
  time, another peer can choose to announce that domain with a weight a bit
  higher than the very low default weight. This mechanism is referred to as
  "pinging a name".

PeerDNS acts as a DNS resolver for all TLDs, meaning it can be used as a
regular DNS server. For the TLDs it handles it will use the trust mechanism to
answer, and for the other TLDs it will proxy the query to a regular DNS server
of the user's choice.


## Installation

Tested on Linux, might work on other OSes as well (please tell me).  Built with
[Elixir](https://elixir-lang.org/), please install that first.

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
mix run --no-halt
```

