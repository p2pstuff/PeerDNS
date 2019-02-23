import React, { Component } from 'react';
import { Table } from 'react-bootstrap';

import { pListPrivileged, pGetNeighbors } from './api';

class Neighbors extends Component {
  constructor() {
    super();
    this.state = { lists: null, data: [] };
  }

  componentDidMount() {
    pListPrivileged()
    .then(pjson =>
      pGetNeighbors()
      .then(json => this.setState({ lists: pjson.peer_lists, data: json.neighbors }))
    );
  }

  render() {
    return (
      <Table striped bordered hover>
        <thead>
          <tr>
            <th>Peer Name</th>
            <th>Trust</th>
            <th>IP</th>
            <th>API port</th>
            <th>Source</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {this.state.data.map((k)=>
              <ListItem key={k.ip} item={k} lists={this.state.lists} />
          )}
        </tbody>
      </Table>
    );
  }
}

function ListItem(props) {
  return (
    <tr>
      <td>{props.item.name}</td>
      <td>{props.item.weight}</td>
      <td>{props.item.ip}</td>
	    <td>{props.item.api_port} </td>
      <td>{props.lists[props.item.source] ?
            props.lists[props.item.source].name :
            props.item.source}</td>
      <td>{props.item.status}</td>
    </tr>
  );
}

export default Neighbors;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
