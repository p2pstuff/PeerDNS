import React, { Component } from 'react';
import { Table } from 'react-bootstrap';
import { Link } from 'react-router-dom';

import { getNameList } from './api';

class List extends Component {
  constructor() {
    super();
    this.state = { data: {} };
  }

  componentDidMount() {
    getNameList()
    .then(json => this.setState({ data: json}));
  }

  render() {
    var domains = Object.keys(this.state.data);
    domains.sort((k1, k2) => this.state.data[k1].weight > this.state.data[k2].weight);
    return (
      <Table striped bordered hover>
        <thead>
          <tr>
            <th>Name</th>
            <th>Weight</th>
            <th>Owner</th>
            <th>Version</th>
          </tr>
        </thead>
        <tbody>
          {domains.map((k)=>
              <ListItem name={k} item={this.state.data[k]} />
          )}
        </tbody>
      </Table>
    );
  }
}

function ListItem(props) {
  return (
    <tr>
      <td>
        <Link to={"/zone/" + props.name + "/" + props.item.pk}>
          {props.name}
        </Link>
      </td>
      <td>{props.item.weight}</td>
      <td>{props.item.pk}</td>
      <td>{props.item.version}</td>
    </tr>
  );
}

export default List;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
