import React, { Component } from 'react';
import { Table } from 'react-bootstrap';
import punycode from 'punycode';

import { getZones } from './api';

class Zone extends Component {
  constructor(args) {
    super();
    this.name = args.match.params.name;
    this.pk = args.match.params.pk;
    this.state = { data: null };
  }

  componentDidMount() {
    var that = this;
    getZones({[this.name]: this.pk})
    .then(function (json) {
      if (json.length > 0)
        that.setState({ data: json[0]})
    });
  }

  render() {
    if (this.state.data == null) {
      return (
        <p>No data...</p>
      );
    } else {
      var pk = this.state.data.pk;
      var data = JSON.parse(this.state.data.json);
      return (
        <>
          <h1>Zone {punycode.toUnicode(data.name)}</h1>
          {data.name !== punycode.toUnicode(data.name) &&
            <p><strong>Encoded as:</strong> {data.name}</p>
          }
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
  var name = props.item[0];
  return (
    <tr>
      <td>
        {punycode.toUnicode(name)}
        {name !== punycode.toUnicode(name) &&
            <><br /><small>{name}</small></>}
      </td>
      <td>{props.item[1]}</td>
      <td>{props.item.slice(2).join(" ")}</td>
    </tr>
  );
}


export default Zone;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
