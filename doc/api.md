# PeerDNS API reference

PeerDNS exposes a REST API open to anyone for data exchange and open to
localhost for privileged access, allowing to edit the peer's trust list and
announced domain names. The default API port is 14123 and it is not recommended
to change it as it is a default value that peers use to contact each other.

This page contains details of the two set of APIs exposed by PeerDNS.
Alternative PeerDNS implementations can be created, all they need for
compatibility is to implement the same set of APIs.

## Common data types

### Name entry

| Name | Type | Description |
| ---- | ---- | ----------- |
| `pk` | string | A url-base64 encoded ed25519 public key used to sign the DNS zone data |
| `weight` | float | The trust value with which the zone is announced |
| `version` | integer | Version of the DNS zone the server has in store |

### Zone data

| Name | Type | Description |
| ---- | ---- | ----------- |
| `json` | string | A json string of the zone data (following table) |
| `pk` | string | A url-base64 encoded ed25519 public key used to sign the DNS zone data |
| `signature` | string | A url-base64 encoded ed25519 signature for the DNS zone data (the JSON string of field `json`) |

The zone data is an object of the following structure:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `version` | integer | Version of the zone data. Newer versions overwrite older versions |
| `name` | string | Name of the DNS zone |
| `entries` | list of entries | DNS entries of the zone |

An entry is a list that describes a DNS entry. The following formats are supported:

- `[name, "A", ipv4_address]`
- `[name, "AAAA", ipv6_address]`
- `[name, "TXT", one_or_more, text_strings]`
- `[name, "CNAME", redirect_name]`
- `[name, "MX", priority, server_name]`

**Example value:**

```
{
"signature": "LBjIeCB7gmFqW1xnuW4DKYGBq1Uag5TlfNja668Eg_ynTylh5mF7eMQfZxsepL7YUWbukd71doL3QQOWRgqNBA",
"pk": "f1mFq-BXhx03K_ZVs6K9l8N7D6ZwiRt-UIuRLfxQe78",
"json": "{\"version\":6,\"name\":\"ipfs11.h\",\"entries\":[[\"ipfs11.h\",\"TXT\",\"Public IPFS gateway, not always up.\"],[\"ipfs11.h\",\"AAAA\",\"fcd8:667a:6f73:442e:b5fc:9191:4039:4a8f\"]]}"
}
```

### Call results

Many API calls simply return a success or error value. These are encoded as
simple JSON objects of the form:

- `{"result": "success"}`
- `{"result": "error", "reason": xxx}`


## Public API

The public API is exposed under the path `/api`.

### `GET /api` - get node information

**Arguments:** none

**Returns:** a JSON object of the form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `api` | string | Constant value: `PeerDNS` |
| `server` | string | Name of the server software |
| `version` | string | Version of the PeerDNS server |
| `tld` | array of string | List of top-level domains for which this server is active |
| `privileged` | boolean | Is the client IP allowed to call the privileged API? |
| `operator` | map of string to string | Operator contact information |

**Example:**

```
$ curl localhost:14123/api
{
  "version": "0.1.0",
  "tld": [
    ".p2p",
    ".mesh",
    ".h",
    ".hype",
    ".fc00"
  ],
  "server": "PeerDNS",
  "privileged": true,
  "operator": {
    "Name": "your name or nickname here",
    "IRC": "your IRC handle here",
    "E-mail": "your E-mail address here"
  },
  "api": "PeerDNS"
}
```

### `GET /api/names/pull` - get the list of names announced by this node

**Arguments:**

- Optionnal GET parameter: `cutoff`, a float. All names announced with a weight
  smaller than the specified value are not returned. Defaults to zero.

**Returns:** a JSON object where keys are zone names and values are name entries (described above)


**Example:**

```
$ curl localhost:14123/api/names/pull
{
  "stuff.p2p": {
    "weight": 0.9,
    "version": 3,
    "pk": "-7UrW177FGfcVdPcLWE-kGSdVeGANeEwKYRTN-2Xqhc"
  },
  "not-a-real-domain.mesh": {
    "weight": 0.1,
    "version": 0,
    "pk": "VFp7TXbZ4slf4jMyjHHKsubEWHdIzAIUMdRArfqGoSZ"
  },
  "ipfs11.h": {
    "weight": 1,
    "version": 6,
    "pk": "f1mFq-BXhx03K_ZVs6K9l8N7D6ZwiRt-UIuRLfxQe78"
  }
}
```

### `POST /api/zones/pull` - pull zone data for specified names

**POST data content-type:** `application/json`

**Arguments:** The POST data is a JSON object with the following fields:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `request` | map of string to string | A map where keys are zone names and values are public keys of the zone we are requesting |

**Return value:** Returns a list of zone entries (described above)

**Example:**

```
$ curl localhost:14123/api/zones/pull -X POST \
			-H "Content-Type: application/json" \
			-d '{"request":{"ipfs11.h":"f1mFq-BXhx03K_ZVs6K9l8N7D6ZwiRt-UIuRLfxQe78"}}' 
[
  {
    "signature": "LBjIeCB7gmFqW1xnuW4DKYGBq1Uag5TlfNja668Eg_ynTylh5mF7eMQfZxsepL7YUWbukd71doL3QQOWRgqNBA",
    "pk": "f1mFq-BXhx03K_ZVs6K9l8N7D6ZwiRt-UIuRLfxQe78",
    "json": "{\"version\":6,\"name\":\"ipfs11.h\",\"entries\":[[\"ipfs11.h\",\"TXT\",\"Public IPFS gateway, not always up.\"],[\"ipfs11.h\",\"AAAA\",\"fcd8:667a:6f73:442e:b5fc:9191:4039:4a8f\"]]}"
  }
]
```


### `POST /api/push` - push updates

**POST data content-type:** `application/json`

**Arguments:** The POST data is a JSON object with the following fields:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `added` | list of name entry | Added or modified names |
| `removed` | list of string | Removed names |
| `zones` | list of zone data | Zone data for new names or updated versions |

**Return value:** A call result JSON object.


## Privileged API

The privileged API is exposed under the path `/api/privileged`.

### `GET /api/privileged` - get server information

**Arguments:** none

**Returns:** a JSON object of the form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `sources` | map string to source info | The list of sources (name and zone databases) announced by this PeerDNS instance. The keys of this object are the identifiers of the sources. |
| `peer_lists` | map string to peer list info | The list of peer lists used by this server. |

A source info map is in the following form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | Full name of this source |
| `description` | string | Description of the source, as defined in the config file |
| `weight` | float | Multiplicator for the weight of all entries in this source |
| `editable` | bool | Can the user edit the data? |

A peer list info map is in the following form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | Full name of this peer list |
| `description` | string | Description of the peer list, as defined in the config file |
| `editable` | bool | Can the user edit the data? |
| `temporary` | bool | If true, all peers in the list are deleted when PeerDNS restarts, otherwise they are saved |

**Example:**

```
{
  "sources": {
    "my_modlist": {
      "weight": 0.8,
      "name": "My modlist",
      "editable": true,
      "description": "Use this list to propagate or block domains of other users."
    },
    "my_domains": {
      "weight": 1,
      "name": "My domains",
      "editable": true,
      "description": "Use this list to enter domains you own."
    }
  },
  "peer_lists": {
    "trust_list": {
      "temporary": false,
      "name": "Trust list",
      "editable": true,
      "description": "Use this list to enter peers you trust personnally. This list is saved to disk at each change and will be reloaded when PeerDNS restarts."
    },
    "temporary_peers": {
      "temporary": true,
      "name": "Temporary peers",
      "editable": true,
      "description": "Use this list to add temporary peers. This list will be cleared whenever PeerDNS restarts."
    }
  }
}
```

### `POST /api/privileged/pull` - start a full pull of data from neighbors

**Arguments:** none

**Return value:** A call result JSON object.

**Example:**

```
$ curl localhost:14123/api/privileged/pull -X POST
{
  "result": "success"
}
```

### `GET /api/privileged/neighbors` - list neighbors

**Arguments:** none

**Returns:**

| Name | Type | Description |
| ---- | ---- | ----------- |
| `neighbors` | list of peer info | The list of currently known neighbors |

A peer info is an object of the form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | Peer name |
| `ip` | string | Peer IP address |
| `api_port` | integer | Port for API connections |
| `weight` | float | Trust value, multiplicator applied to all incoming entries from that peer |
| `status` | string | "up" or "down": were we successfull last time we tried to contact them? |
| `source` | string | Where do we know this peer from? ID of a peer list or `CJDNS` |

**Example:**

```
$ curl localhost:14123/api/privileged/neighbors
{
  "neighbors": [
    {
      "weight": 0.9,
      "status": "up",
      "source": "Trust list",
      "name": "fly11",
      "ip": "fc18:e736:105d:d49a:2ab5:14a2:698f:7021",
      "api_port": 14123
    }
  ]
}
```

### `GET /api/privileged/check` - check name status

**Parameters:** A single GET parameter: `name`, the name whose status we want to check.

**Returns:**

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | The queried name |
| `valid` | boolean | Is the name a valid zone name for a TLD handled by this PeerDNS server? |
| `taken` | boolean | Are we aware of another user announcing this name? |

**Example:**

```
$ curl localhost:14123/api/privileged/check?name=peerdns.hype
{
  "valid": true,
  "taken": true,
  "name": "peerdns.hype"
}
```

### `GET /api/privileged/source/<id>` - list names and zones in source

**Parameters:** `<id>` the short identifier of the source we are querying

**Returns:**

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | Name of the source |
| `description` | string | Description of the source, as defined in the config file |
| `zones` | map string to partial zone data | Our announced DNS zones and all their data |
| `names` | map string to partial name data | Our announced names |

A zone data entry contains only the version number and the list of DNS
entries of that zone. A name entry contains only the public key and the
weight we associate to that name.

**Example:**

```
$ curl localhost:14123/api/privileged/source/my_domains
{
  "name": "My domains",
  "description": "Use this list to enter domains you own.",
  "zones": {
    "peerdns.hype": {
      "version": 4,
      "entries": [
        [
          "peerdns.hype",
          "AAAA",
          "fc18:e736:105d:d49a:2ab5:14a2:698f:7021"
        ]
      ]
    }
  },
  "names": {
    "peerdns.hype": {
      "weight": 1,
      "pk": "nx_WH3M0Bxp-7v2-neF95Q2dtdvlIa4w3FEWxOiZSM0"
    }
  }
}
```

### `POST /api/privileged/source/<id>` - change names and zones in source

**POST data content-type:** `application/json`

**Arguments:** `<id>` the short identifier of the source we are modifying. The POST data is a JSON object with the following fields:

| Name | Type | Only for | Description |
| ---- | ---- | -------- | ----------- |
| `action` | string | mandatory | `add_name`, `del_name`, `add_zone`, `del_zone` |
| `name` | string | mandatory | DNS name we want to change |
| `pk` | string | `add_name` | The public key we want to associate with that name |
| `weight` | string | `add_name`, `add_zone` | The weight we want to associate with that name |
| `entries` | list of DNS entries | `add_zone` | The new set of DNS entries for that zone. If present, all entries are replaced by the ones specified here. If absent, no change is made. |

The `add_name` and `add_zone` operations are also used to edit name and
zone data: if a previous name or zone exists with the name given as an
argument, then the previous data is replaced to the data given in the call.

**Return value:** A call result JSON object.

**Examples:**

```
$ curl localhost:14123/api/privileged/source/my_domains -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "add_name", "name": "peerdns.hype", "pk": "nx_WH3M0Bxp-7v2-neF95Q2dtdvlIa4w3FEWxOiZSM0", "weight": 1.0}'
{
  "result": "success"
}

$ curl localhost:14123/api/privileged/source/my_domains -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "del_name", "name": "peerdns.hype"}'
{
  "result": "success"
}

$ curl localhost:14123/api/privileged/source/my_domains -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "add_zone", "name": "test.fc00", "weight": 1.0, "entries": [["test.fc00", "A", "1.2.3.4"]]}' 
{
  "result": "success"
}

$ curl localhost:14123/api/privileged/source/my_domains -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "del_zone", "name": "test.fc00"}'
{
  "result": "success"
}
```

### `GET /api/privileged/peer_list/<id>` - get peer list

**Parameters:** `<id>` the short identifier of the peer list we are querying

**Returns:** An object with the following fields:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | The name of the peer list |
| `description` | string | The description of the peer list |
| `peer_list` | list of peer list entry | List of peers |

A peer list entry is of the form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `name` | string | The name given to the peer |
| `ip` | string | IP address to contact the peer |
| `api_port` | integer | API port to contact the peer |
| `weight` | float | The trust value given to that peer |

**Example:**

```
$ curl localhost:14123/api/privileged/peer_list/trust_list
{
  "name": "Trust list",
  "description": "Use this list to enter peers you trust personnally. This list is saved to disk at each change and will be reloaded when PeerDNS restarts.",
  "peer_list": [
    {
      "weight": 0.9,
      "name": "fly11",
      "ip": "fc18:e736:105d:d49a:2ab5:14a2:698f:7021",
      "api_port": 14123
    }
  ]
}
```

### `POST /api/privileged/peer_list/<id>` - alter peer list

**POST data content-type:** `application/json`

**Arguments:** `<id>` the short identifier of the peer list we are modifying. The POST data is a JSON object with the following fields:

| Name | Type | Only for | Description |
| ---- | ---- | -------- | ----------- |
| `action` | string | mandatory | `add`, `del` or `clear_all` |
| `ip` | string | `add`, `del` | IP address of the peer we want to add or delete |
| `name` | string | `add` | The name to give to the peer |
| `api_port` | integer | `add` | API port to contact the peer |
| `weight` | float | `add` | Weight/trust value given to the peer. MUST BE SMALLER THAN 1! |

The `add` operation is also used to modify a peer: if a peer already exists
with that IP address, it is modified with the values given as an argument
to this call.

**Return value:** A call result JSON object.

**Examples:**

```
$ curl localhost:14123/api/privileged/peer_list/trust_list -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "add", "ip": "fc18:e736:105d:d49a:2ab5:14a2:698f:7021", "name": "fly11", "weight": 0.9, "api_port": 14123}'
{
  "result": "success"
}

$ curl localhost:14123/api/privileged/peer_list/trust_list -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "del", "ip": "fc18:e736:105d:d49a:2ab5:14a2:698f:7021"}'
{
  "result": "success"
}

$ curl localhost:14123/api/privileged/peer_list/temporary_peers -X POST \
	-H "Content-Type: application/json" \
	-d '{"action": "clear_all"}'
{
  "result": "success"
}
```
