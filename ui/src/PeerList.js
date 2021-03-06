
import React, { Component } from 'react';
import { Table, Alert, Form, Modal, Button } from 'react-bootstrap';

import { pGetPeerList, pPeerListAdd, pPeerListDel } from './api';

import Confirm from './Confirm';

class PeerList extends Component {
  constructor(args) {
    super();
	  this.id = args.match.params.id;
    this.state = { data: null, error: null };
  }

  componentDidMount() {
    pGetPeerList(this.id)
    .then(json => this.setState({ name: json.name, description: json.description, data: json.peer_list }));
  }

  reload() {
    this.componentDidMount();
  }
  
  deleteEntry(ip) {
    var that = this;
    pPeerListDel(this.id, ip)
    .then(function (json) {
      if (json.result ==="success") {
        that.reload();
      } else {
        that.setState({ error: json.reason });
      }
    });
  }

  render() {
	  if (this.state.data == null) {
      return (
        <p>Loading...</p>
      );
    } else {
        return (
          <>
            <h1>{this.state.name}</h1>
            <p>{this.state.description}</p>
            {this.state.error &&
                <Alert variant="danger">{this.state.error}</Alert>}
            {this.state.data.length === 0
                ? <p>No entries.</p> :
              <Table striped bordered hover>
                <thead>
                  <tr>
                    <th>Peer Name</th>
                    <th>IP</th>
                    <th>API port</th>
                    <th>Trust</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {this.state.data.map((item) =>
                      <PeerListItem key={item.ip} item={item}
                        peer_list={this.id}
                        onChange={this.reload.bind(this)}
                        onDelete={this.deleteEntry.bind(this, item.ip)} />
                  )}
                </tbody>
              </Table>
            }
            <PeerEntryForm
                peer_list={this.id}
                variant="success" title="Add trust list entry" actionText="Add"
                onDone={this.reload.bind(this)} />
          </>
        );
    }
  }
}

function PeerListItem(props) {
  return (
    <tr>
      <td>{props.item.name}</td>
      <td>{props.item.ip}</td>
      <td>{props.item.api_port}</td>
      <td>{props.item.weight}</td>
      <td>
        <PeerEntryForm ipRO={true} 
          peer_list={props.peer_list}
          ip={props.item.ip} name={props.item.name}
          weight={props.item.weight} api_port={props.item.api_port}
          title="Edit entry"
          variant="primary"
          actionText="Edit"
          onDone={props.onChange} />
        &nbsp;
        <Confirm title="Are you sure?"
          text="Do you really want to delete this entry?"
          variant="danger"
          actionText="Delete"
          onConfirm={props.onDelete} />
      </td>
    </tr>
  );
}

class PeerEntryForm extends Component {
  constructor(props, context) {
    super(props, context);

    this.state = {
      show: false,
      err: null,
      name: props.name || "",
      ip: props.ip || "",
      api_port: props.pk || "14123",
      weight: props.weight || "0.9",
    };
  }

  handleClose(retval) {
    if (retval) {
      var that = this;
      pPeerListAdd(this.props.peer_list,
        this.state.name, this.state.ip,
        parseInt(this.state.api_port), parseFloat(this.state.weight))
      .then(function(json) {
        if (json.result === "success") {
          that.setState({
            error: null,
            show: false,
          });
          that.props.onDone();
        } else {
          that.setState({ err: json.reason });
        }
      });
    } else {
      this.setState({ show: false });
    }
  }

  handleOpen() {
    this.setState({ show: true });
  }

  handleInputChange(event) {
    const target = event.target;
    const value = target.type === 'checkbox' ? target.checked : target.value;
    const name = target.name;

    this.setState({
      [name]: value
    });
  }

  render() {
    return (
      <>
        <Button variant={this.props.variant} onClick={this.handleOpen.bind(this)}>
          {this.props.actionText}
        </Button>
        <Modal show={this.state.show} onHide={this.handleClose.bind(this, false)}>
          <Modal.Header closeButton>
            <Modal.Title>{this.props.title}</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            {this.state.err &&
                <Alert variant="danger">{this.state.err}</Alert>}
            <Form>
              <Form.Group controlId="formName">
                <Form.Label>Peer Name</Form.Label>
                <Form.Control type="text" name="name" onChange={this.handleInputChange.bind(this)}
                  placeholder="Name" value={this.state.name} />
              </Form.Group>
              <Form.Group controlId="formIp">
                <Form.Label>IP</Form.Label>
                { this.props.ipRO
                  ? <Form.Control name="ip" onChange={this.handleInputChange.bind(this)}
                        type="text" placeholder="fc00:..." value={this.state.ip} readOnly />
                  : <Form.Control name="ip" onChange={this.handleInputChange.bind(this)}
                        type="text" placeholder="fc00:..." value={this.state.ip} />
                }
              </Form.Group>
              <Form.Group controlId="formPort">
                <Form.Label>API port</Form.Label>
                <Form.Control type="text" name="api_port" onChange={this.handleInputChange.bind(this)}
                  placeholder="14123" value={this.state.api_port} />
              </Form.Group>
              <Form.Group controlId="formWeight">
                <Form.Label>Trust value</Form.Label>
                <Form.Control type="text" name="weight" onChange={this.handleInputChange.bind(this)}
                  placeholder="0.9" value={this.state.weight} />
                <Form.Text className="text-muted">
                  The trust value of a peer corresponds to the trust you have in that peer.
                  Trust values must be bigger than 0 and smaller than 1.
                </Form.Text>
              </Form.Group>
            </Form>
          </Modal.Body>
          <Modal.Footer>
            <Button variant="secondary" onClick={this.handleClose.bind(this, false)}>
              Cancel
            </Button>
            <Button variant={this.props.variant} onClick={this.handleClose.bind(this, true)}>
              {this.props.actionText}
            </Button>
          </Modal.Footer>
        </Modal>
      </>
    );
  }

}


export default PeerList;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
