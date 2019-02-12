import axios from 'axios';

var api_base = "http://localhost:14123/api";

function getNodeInfo() {
  return axios.get(api_base)
    .then((ret) => ret.data);
}

export default getNodeInfo;
