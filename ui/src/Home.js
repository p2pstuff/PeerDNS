import React, { Component } from 'react';

import { getNodeInfo } from './api';

class Home extends Component {
  render() {
    var node_info = getNodeInfo();
    var tldlist = node_info.tld;
    return (
      <>
        <p>This is a PeerDNS server for the following TLDs:</p>
        <ul>
          {tldlist.map((k) => <li>{k}</li>)}
        </ul>
        <p><strong>Operator contact information:</strong></p>
        <ul>
          {Object.keys(node_info.operator).map((k)=>
            <li>
              <strong>{k}:</strong> {node_info.operator[k]}
            </li>
          )}
        </ul>
        <p><strong>Version:</strong> {node_info.version}</p>
      </>
    );
  }
}

export default Home;
//
// vim: set sts=2 ts=2 sw=2 tw=0 et :
