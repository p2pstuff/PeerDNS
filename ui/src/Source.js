import React, { Component } from 'react';
import { Table, Alert, Form, Modal, Button } from 'react-bootstrap';

import { pGetSource, pAddName, pDelName, pAddZone } from './api';

import ZoneEditor from './ZoneEditor';

import Confirm from './Confirm';

class Source extends Component {
  constructor(args) {
    super();
	  this.id = args.match.params.id;
    this.state = { data: null, error: null };
  }

  componentDidMount() {
    pGetSource(this.id)
    .then(json => this.setState({ data: json }));
  }

  reload() {
    this.componentDidMount();
  }

  deleteName(n) {
    var that = this;
    pDelName(this.id, n)
    .then(function (json) {
      if (json.result === "success") {
        that.reload();
      } else {
        that.setState({error: json.reason});
      }
    });
  }

  render() {
	  if (this.state.data == null) {
      return (
        <p>Loading...</p>
      );
    } else {
        var names = this.state.data.names;
        var zones = this.state.data.zones;
        return (
          <>
            {this.state.error &&
                <Alert variant="danger">{this.state.error}</Alert>}
            <h1>Zones</h1>
            {Object.keys(zones).length === 0 ? <p>No zones defined.</p> :
              Object.keys(zones).map((k)=>
                <ZoneEditor key={k}
                  source={this.id} name={k}
                  zentry={zones[k]} nentry={names[k]}
                  onChange={this.reload.bind(this)} />
              )
            }
            <ZoneAddForm sourceId={this.id} variant="success" title="Create new zone"
              actionText="Create" onDone={this.reload.bind(this)} />
            <hr />
            <h1>Names</h1>
            {Object.keys(names).filter((k) => zones[k] === undefined).length === 0
                ? <p>No names defined.</p> :
              <Table striped bordered hover>
                <thead>
                  <tr>
                    <th>Domain Name</th>
                    <th>Weight</th>
                    <th>Public key</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {Object.keys(names).filter((k) => zones[k] === undefined).map((k)=>
                      <NameListItem key={k} name={k} item={names[k]}
                        sourceId={this.id}
                        onChange={this.reload.bind(this)}
                        onDelete={this.deleteName.bind(this, k)} />
                  )}
                </tbody>
              </Table>
            }
            <NameForm sourceId={this.id}
                variant="success" title="Add name entry" actionText="Add"
                onDone={this.reload.bind(this)} />
          </>
        );
    }
  }
}

function NameListItem(props) {
  return (
    <tr>
      <td>
        {props.name}
      </td>
      <td>{props.item.weight}</td>
      <td>{props.item.pk}</td>
      <td>
        <NameForm sourceId={props.sourceId} name={props.name}
          nameRO={true} pk={props.item.pk} weight={props.item.weight}
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

class NameForm extends Component {
  constructor(props, context) {
    super(props, context);

    this.state = {
      show: false,
      err: null,
      name: props.name || "",
      pk: props.pk || "",
      weight: props.weight || "1.0",
    };
  }

  handleClose(retval) {
    if (retval) {
      var that = this;
      pAddName(this.props.sourceId, 
        this.state.name, this.state.pk, parseFloat(this.state.weight))
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
                <Form.Label>Domain Name</Form.Label>
                { this.props.nameRO
                  ? <Form.Control name="name" onChange={this.handleInputChange.bind(this)}
                        type="text" placeholder="Name" value={this.state.name} readOnly />
                  : <Form.Control name="name" onChange={this.handleInputChange.bind(this)}
                        type="text" placeholder="Name" value={this.state.name} />
                }
              </Form.Group>
              <Form.Group controlId="formPK">
                <Form.Label>Public key</Form.Label>
                <Form.Control type="text" name="pk" onChange={this.handleInputChange.bind(this)}
                  placeholder="VFp7TXbZ4..." value={this.state.pk} />
              </Form.Group>
              <Form.Group controlId="formWeight">
                <Form.Label>Weight</Form.Label>
                <Form.Control type="text" name="weight" onChange={this.handleInputChange.bind(this)}
                  placeholder="1.0" value={this.state.weight} />
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


class ZoneAddForm extends Component {
  constructor(props, context) {
    super(props, context);

    this.state = {
      show: false,
      err: null,
      name: props.name || "",
    };
  }

  handleClose(retval) {
    if (retval) {
      var that = this;
      pAddZone(this.props.sourceId, this.state.name, null, 1.0)
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
                <Form.Label>Domain Name</Form.Label>
                <Form.Control name="name" onChange={this.handleInputChange.bind(this)}
                      type="text" placeholder="Name" value={this.state.name} />
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

export default Source;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
