import axios from 'axios';

var api_base = (process.env.NODE_ENV === "production"
  ? "/api" : "http://localhost:14123/api");

var node_info = null;

function init() {
  return axios.get(api_base)
    .then((ret) => node_info = ret.data);
}

function getNodeInfo() {
  return node_info;
}

function getNameList(cutoff) {
  cutoff = cutoff || 0.0;
  return axios.get(api_base + "/names/pull?cutoff=" + cutoff)
    .then((ret) => ret.data);
}

function getZones(zone_query) {
  return axios.post(api_base + "/zones/pull",
      {"request": zone_query})
  .then((ret) => ret.data);
}

function isPrivileged() {
  return node_info.privileged;
}

function pListSources() {
  return axios.get(api_base + "/privileged")
    .then((ret) => ret.data);
}

function pGetSource(id) {
  return axios.get(api_base + "/privileged/source/" + id)
    .then((ret) => ret.data);
}

function pGetNeighbors() {
  return axios.get(api_base + "/privileged/neighbors")
    .then((ret) => ret.data);
}

function pCheckName(name) {
  return axios.get(api_base + "/privileged/check",
    { params: {name: name} })
  .then((ret) => ret.data);
}

function pAddName(source_id, name, pk, weight) {
  return axios.post(api_base + "/privileged/source/" + source_id,
      {
        "action": "add_name",
        "name": name,
        "pk": pk,
        "weight": weight
      })
  .then((ret) => ret.data);
}

function pDelName(source_id, name) {
  return axios.post(api_base + "/privileged/source/" + source_id,
      {
        "action": "del_name",
        "name": name,
      })
  .then((ret) => ret.data);
}

function pAddZone(source_id, name, entries, weight) {
  return axios.post(api_base + "/privileged/source/" + source_id,
      {
        "action": "add_zone",
        "name": name,
        "entries": entries,
        "weight": weight
      })
  .then((ret) => ret.data);
}

function pDelZone(source_id, name) {
  return axios.post(api_base + "/privileged/source/" + source_id,
      {
        "action": "del_zone",
        "name": name,
      })
  .then((ret) => ret.data);
}

function pGetTrustList() {
  return axios.get(api_base + "/privileged/trustlist")
    .then((ret) => ret.data);
}

function pTrustListAdd(name, ip, api_port, weight) {
  return axios.post(api_base + "/privileged/trustlist",
      {
        "action": "add",
        "name": name,
        "ip": ip,
        "api_port": api_port,
        "weight": weight,
      })
  .then((ret) => ret.data);
}

function pTrustListDel(ip) {
  return axios.post(api_base + "/privileged/trustlist",
      {
        "action": "del",
        "ip": ip,
      })
  .then((ret) => ret.data);
}

export { init, getNodeInfo, getNameList, getZones, isPrivileged,
    pListSources, pGetSource, pGetNeighbors,
    pCheckName, pAddName, pDelName, pAddZone, pDelZone,
    pGetTrustList, pTrustListAdd, pTrustListDel };

// vim: set sts=2 ts=2 sw=2 tw=0 et :
