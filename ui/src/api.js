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


export { init, getNodeInfo, getNameList, getZones, isPrivileged };
