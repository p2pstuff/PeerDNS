import React, { Component } from 'react';
import { Table } from 'react-bootstrap';

import { pGetNeighbors } from './api';

class Neighbors extends Component {
  constructor() {
    super();
    this.state = { data: [] };
  }

  componentDidMount() {
    pGetNeighbors()
    .then(json => this.setState({ data: json.neighbors }));
  }

  render() {
    return (
      <Table striped bordered hover>
        <thead>
          <tr>
            <th>Name</th>
            <th>Trust</th>
            <th>IP</th>
            <th>API port</th>
            <th>Source</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {this.state.data.map((k)=>
              <ListItem key={k.ip} item={k} />
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
      <td>{props.item.source}</td>
      <td>{props.item.status}</td>
    </tr>
  );
}

export default Neighbors;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
