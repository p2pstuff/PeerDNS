# PeerDNS

A peer-to-peer DNS system based on a Web of Trust.

Designed to work with CJDNS, strongly inspired by
<https://docs.meshwith.me/notes/dns.html>.

Talk: join the `#peerdns` channel on `irc.fc00.io`.


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

Tested on Linux, might work on other OSes as well (please tell me).

PeerDNS runs a DNS server, meaning it needs to bind port 53.  You can run it as
root but it is highly discouraged!  A better solution is to allow non-root user
to bind privileged ports, or to use an alternative port and tunnel your port 53
in some way or another. 

### Linux steps

Install [Elixir](https://elixir-lang.org/) and `libsodium`. If your
distribution has separate packages for development headers, you might need to
install `libsodium-dev` as well.

[Here](https://stackoverflow.com/questions/413807/is-there-a-way-for-non-root-processes-to-bind-to-privileged-ports-on-linux)
is a list of ways to bind privileged ports as an unprivilege users.

This is an easy method but a quite bad one:

```
sudo sysctl net.ipv4.ip_unprivileged_port_start=53
```

### macOS steps

Install [Elixir](https://elixir-lang.org/) and `libsodium`. If your package
manager has separate packages for development headers, you might need to
install `libsodium-dev` as well.

(insert here solution for binding port 53 as non-root user)

### Common steps

Clone this repo and download Elixir dependencies:

```
git clone https://github.com/p2pstuff/PeerDNS
cd PeerDNS
mix deps.get
```

Copy `config/config.exs.sample` to `config/config.exs` and edit to your needs.
Typically, you will want to add a few trusted peers to exchange data with. A
few are provided in the sample but you might want to use other ones.

**OPTIONAL** To serve the web UI locally instead of using a hosted version,
you can download precompiled files to the `ui` directory:

```
cd ui
wget http://peerdns.p2pstuff.xyz/peerdns-ui-build.tgz
tar xzvf peerdns-ui-build.tgz
cd ..
```

If you prefer to compile the UI yourself, install `npm` and run the following
commands:

```
cd ui
npm install
npm run build
cd ..
```

**END OPTIONAL**

Run PeerDNS:

```
mix run --no-halt
```

To be able to access PeerDNS domains as regular domains, you must replace your
system's DNS servers to be `127.0.0.1`, so that the local PeerDNS instance will
be queried instead of your network's original DNS server.

PeerDNS also starts an API server at `http://localhost:14123`, which provides a
user interface to create domains and edit your trust list.


## PeerDNS API

There is no CLI utility yet to administrate your PeerDNS instance, however the
JSON API can be easily called from the command line using `curl`. Here are a
few examples:

```
# Get the trust list
curl localhost:14123/api/privileged/peer_list/trust_list
# Add a peer
curl localhost:14123/api/privileged/peer_list/trust_list -d '{"action":"add","ip":"fc00:1234::1","name":"Test peer","api_port":14123,"weight":0.5}' -v -H "Content-Type: application/json"
# Remove a peer
curl localhost:14123/api/privileged/peer_list/trust_list -d '{"action":"del","ip":"fc00:1234::1"}' -v -H "Content-Type: application/json"
```

The API documentation is found in `doc/api.md`.


## Docker notes (WIP)

```
docker build . -t peerdns
docker run --network host -it peerdns /bin/bash
```
