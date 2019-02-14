import React, { Component } from 'react';
import { Table } from 'react-bootstrap';

import { getZones } from './api';

class Zone extends Component {
  constructor(args) {
    super();
    this.name = args.match.params.name;
    this.pk = args.match.params.pk;
    this.state = { data: null };
  }

  componentDidMount() {
    getZones({[this.name]: this.pk})
    .then(json => this.setState({ data: json}));
  }

  render() {
    if (this.state.data == null) {
      return (
        <p>Loading...</p>
      );
    } else {
      var pk = this.state.data[0].pk;
      var data = JSON.parse(this.state.data[0].json);
      return (
        <>
          <h1>Zone {data.name}</h1>
          <p><strong>Public key:</strong> {pk}</p>
          <p><strong>Version:</strong> {data.version}</p>
          <Table striped bordered hover>
            <thead>
              <tr>
                <th>Domain Name</th>
                <th>Type</th>
                <th>Value</th>
              </tr>
            </thead>
            <tbody>
              {data.entries.map((item)=>
                  <ListItem key={item.join(" ")} item={item} />
              )}
            </tbody>
          </Table>
        </>
      );
    }
  }
}

function ListItem(props) {
  return (
    <tr>
      <td>
        {props.item[0]}
      </td>
      <td>{props.item[1]}</td>
      <td>{props.item.slice(2).join(" ")}</td>
    </tr>
  );
}


export default Zone;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
