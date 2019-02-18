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

*Example value:*

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

*Arguments:* none

*Returns:* a JSON object of the form:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `api` | string | Constant value: `PeerDNS` |
| `server` | string | Name of the server software |
| `version` | string | Version of the PeerDNS server |
| `tld` | array of string | List of top-level domains for which this server is active |
| `privileged` | boolean | Is the client IP allowed to call the privileged API? |
| `operator` | map of string to string | Operator contact information |

*Example return value:*

```
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

*Arguments:*

- Optionnal GET parameter: `cutoff`, a float. All names announced with a weight
  smaller than the specified value are not returned. Defaults to zero.

*Returns:* a JSON object where keys are zone names and values are name entries (described above)


*Example return value:*

```
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

*POST data content-type:* `application/json`

*Arguments:* The POST data is a JSON object with the following fields:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `request` | map of string to string | A map where keys are zone names and values are public keys of the zone we are requesting |

*Return value:* Returns a list of zone entries (described above)

*Example:*

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

*POST data content-type:* `application/json`

*Arguments:* The POST data is a JSON object with the following fields:

| Name | Type | Description |
| ---- | ---- | ----------- |
| `added` | list of name entry | Added or modified names |
| `removed` | list of string | Removed names |
| `zones` | list of zone data | Zone data for new names or updated versions |

*Return value:* A call result JSON object.


## Privileged API

The privileged API is exposed under the path `/api/privileged`.

### `GET /api/privileged` - get server information

TODO

### `POST /api/privileged/pull` - start a full pull of data from neighbors

TODO

### `GET /api/privileged/neighbors` - list neighbors

TODO

### `GET /api/privileged/check` - check name status

TODO

### `GET /api/privileged/source/<id>` - list names and zones in source

TODO

### `POST /api/privileged/source/<id>` - change names and zones in source

TODO

### `GET /api/privileged/trustlist` - get trust list

TODO

### `POST /api/privileged/trustlist` - alter trust list

TODO
