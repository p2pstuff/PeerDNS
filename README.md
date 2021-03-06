# PeerDNS

A peer-to-peer DNS system based on a Web of Trust.

Designed to work with CJDNS and Yggdrasil, strongly inspired by
<https://docs.meshwith.me/notes/dns.html>.

Talk: join the `#peerdns` channel through one of the following means:

- CJDNS IRC: `#peerdns` on server `h.irc.cjdns.fr`
- Yggdrasil IRC: `#peerdns` on server `y.irc.cjdns.fr`
- Clearnet Matrix: `#peerdns:matrix.org`

Contents of this file:

- [How it works](#how-it-works)
- [Configuration files](#configuration-files)
- [Running with Docker](#running-with-docker)
- [Running without Docker](#running-without-docker)
- [API examples](#peerdns-api-examples)

Other documentation topics:

- [API calls reference](doc/api.md)
- [Protocol reference](doc/protocol.md)

PeerDNS is released under the GPLv3 license.

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


## Configuration files

PeerDNS can be configured by creating `.exs` scripts in the data directory.
The location of the data directory depends on your installation method (see
below).

You will typically want to create at least one configuration file called
`local.exs` in your data directory. The values defined in this config file will
overwrite the defaults that are provided in the `config/config.exs` file, which
you can read as a reference. DO NOT edit `config/config.exs` directly.

Typically, you will want to add a few trusted peers to exchange data with.
Here is a template `local.exs` file:

```elixir
use Mix.Config

config :peerdns, operator: %{
  "Name" => "your name",
  "IRC" => "your IRC handle",
}

# Automatically add our CJDNS neighbors as peers
config :peerdns, :cjdns_neighbors, enable: true

# Change the default peer list
config :peerdns, :peer_lists, trust_list: [
  default: [
	[name: "<peer name>", ip: "<peer IP>", api_port: 14123, weight: 0.8]
  ]
]
```

You may use several `.exs` files in the data directory as config files, they
will all be loaded when PeerDNS starts.


## Running with Docker

A Docker image has been pushed to the Docker hub at `p2pstuff/peerdns`.

To use it, first create a directory for your persistent PeerDNS configuration
and data files:

```sh
PEERDNS_DATA=/path/to/your/data/directory
mkdir -p $PEERDNS_DATA
```

Create configuration files in the data directory `$PEERDNS_DATA` as explained
[above](#configuration-files).

Run the Docker container with the following command:

```sh
docker run -v $PEERDNS_DATA:/opt/peerdns/data --network host p2pstuff/peerdns:latest
```


## Running without Docker

I'm developping PeerDNS on Linux so that's where it will work the best. It has
also been sucessfully installed on macOS.

PeerDNS runs a DNS server, meaning it needs to bind port 53.  You can run it as
root but it is highly discouraged!  A better solution is to allow non-root user
to bind privileged ports, or to use an alternative port and tunnel your port 53
in some way or another. 

### Linux steps

Install the `libsodium` crypto library. If your distribution has separate
packages for development headers, you might need to install `libsodium-dev` as
well.

Install the [Elixir](https://elixir-lang.org/) programming language.  If your
distribution does not have a recent enough version of Elixir (required: `1.8`
or later), you can install it through [asdf](https://github.com/asdf-vm/asdf).

[Here](https://stackoverflow.com/questions/413807/is-there-a-way-for-non-root-processes-to-bind-to-privileged-ports-on-linux)
is a list of ways to bind privileged ports as an unprivilege users.

This is an easy method but a quite bad one:

```sh
sudo sysctl net.ipv4.ip_unprivileged_port_start=53
```

### macOS steps

Install the `libsodium` crypto library. If your package manager has separate
packages for development headers, you might need to install `libsodium-dev` as
well.

Install the [Elixir](https://elixir-lang.org/) programming language.  If your
package manager does not have a recent enough version of Elixir (required:
`1.8` or later), you can install it through
[asdf](https://github.com/asdf-vm/asdf).

(insert here solution for binding port 53 as non-root user)

### Common steps

Clone this repo and download Elixir dependencies:

```sh
git clone https://github.com/p2pstuff/PeerDNS
cd PeerDNS
mix deps.get
```

Create configuration files in the `data/` directory as explained
[above](#configuration-files).

**OPTIONAL** To serve the web UI locally instead of using a hosted version,
you can download precompiled files to the `ui` directory:

```sh
cd ui
wget http://peerdns.p2pstuff.xyz/peerdns-ui-build.tgz
tar xzvf peerdns-ui-build.tgz
cd ..
```

If you prefer to compile the UI yourself, install `npm` and run the following
commands:

```sh
cd ui
npm install
npm run build
cd ..
```

**END OPTIONAL**

Run PeerDNS:

```sh
mix run --no-halt
```

To be able to access PeerDNS domains as regular domains, you must replace your
system's DNS servers to be `127.0.0.1`, so that the local PeerDNS instance will
be queried instead of your network's original DNS server.

PeerDNS also starts an API server at `http://localhost:14123`, which provides a
user interface to create domains and edit your trust list.


## PeerDNS API examples

There is no CLI utility yet to administrate your PeerDNS instance, however the
JSON API can be easily called from the command line using `curl`. Here are a
few examples:

```sh
# Get the trust list
curl localhost:14123/api/privileged/peer_list/trust_list
# Add a peer
curl localhost:14123/api/privileged/peer_list/trust_list -d '{"action":"add","ip":"fc00:1234::1","name":"Test peer","api_port":14123,"weight":0.5}' -v -H "Content-Type: application/json"
# Remove a peer
curl localhost:14123/api/privileged/peer_list/trust_list -d '{"action":"del","ip":"fc00:1234::1"}' -v -H "Content-Type: application/json"
```

The API documentation is found in `doc/api.md`.


## Docker notes (WIP)

```sh
docker build . -t p2pstuff/peerdns:0.1.0 --no-cache
docker run -v $(pwd)/data:/opt/peerdns/data --network host -it p2pstuff/peerdns:0.1.0 /bin/bash
docker run -v $(pwd)/data:/opt/peerdns/data --network host p2pstuff/peerdns:0.1.0
```
