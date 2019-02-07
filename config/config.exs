use Mix.Config


# Set info logging level (optionnal)
config :logger, level: :info


# Some trusted peer IPs
# Replace with your own here and when they are used later
peer_fly11 = "fc18:e736:105d:d49a:2ab5:14a2:698f:7021"


# The TLDs for which PeerDNS will handle naming
config :peerdns, tld: [".peer", ".mesh", ".h", ".hype", ".fc00"]

# For other TLDs, DNS requests are proxied to this DNS server
config :peerdns, outside: {"208.67.222.222", 53}

# Where to listen for DNS requests
config :peerdns, listen_dns: [
  # Use either the first two or the second two

  # {"0.0.0.0", 53}   # Open DNS server on IPv4 network
  # {"::", 53}        # Open DNS server on IPv6 network

  {"127.0.0.1", 53},  # Private DNS server on IPv4 network
  {"::1", 53},        # Private DNS server on IPv6 network
]

# Where to listen for PeerDNS API requests
# The PeerDNS API is used by other PeerDNS instances to exchange data with us.
# Recommended: do not change this, let everyone connect.
# Access control is handled below.
config :peerdns, listen_api: [
  {"0.0.0.0", 14123},       # Anyone through IPv4
  {"::", 14123},            # Anyone through IPv6
]

# What hosts are allowed to use the privileged PeerDNS API
# These peers will be allowed to edit all the data files that have editable: true
config :peerdns, privileged_api_hosts: ["127.0.0.1", "::1"]

# The sources of data for our name database
config :peerdns, sources: [
  [
    name: "My domains",
    file: "data/name_list.json",
    editable: true,
    weight: 1,
    ping_to: [{peer_fly11, 14123}],
    ping_interval: 3600*12,   # 12 hours
  ],
  [
    name: "My modlist",
    file: "data/name_mod_list.json",
    editable: true,
    weight: 0.8,
  ],
]

config :peerdns, ping: [
  accept: true,
  max_interval: 3600*24,    # one day
  endorse_after: 3600*24*7, # one week
  weight: 0.6
]

config :peerdns, neighbors: [
  # Use these peers as neighbors in all cases
  {:static, [
    [host: {peer_fly11, 14123}, weight: 0.9, push: true, pull: true]
  ]},
  # Look up our CJDNS neighbors by connecting to local cjdroute and try to
  # use them as neighbors
  {:cjdns, [port: 14123, weight: 0.5, push: true, pull: true]}
]

config :peerdns, open: :accept
config :peerdns, open_weight: 0.1

config :peerdns, cutoff: 0.05

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
