import React, { Component } from 'react';
import { Table, Card, Alert, Form, Modal, Button } from 'react-bootstrap';

import Confirm from './Confirm';

import { pAddZone, pDelZone } from './api';

class ZoneEditor extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  deleteZone() {
    var that = this;
    pDelZone(this.props.source, this.props.name)
    .then(function (json) {
      if (json.result === "success") {
        that.props.onChange();
      } else {
        that.setState({error: json.reason});
      }
    });
  }

  deleteEntry(entry) {
    var that = this;
    var new_entries = this.props.zentry.entries.filter((ent) =>
          JSON.stringify(ent) !== JSON.stringify(entry));
    pAddZone(this.props.source, this.props.name,
        new_entries, this.props.nentry.weight)
    .then(function (json) {
      if (json.result === "success") {
        that.props.onChange();
      } else {
        that.setState({error: json.reason});
      }
    });
  }

  change(replaces, new_st) {
    var new_entry = null;
    if (new_st.type === "MX") {
      new_entry = [new_st.name, "MX", parseInt(new_st.priority), new_st.value];
    } else {
      new_entry = [new_st.name, new_st.type, new_st.value];
    }

    var found = false;
    var new_entries = this.props.zentry.entries;
    for (var i = 0; i < new_entries.length; i++) {
      if (JSON.stringify(new_entries[i]) === JSON.stringify(replaces)) {
        new_entries[i] = new_entry;
        found = true;
        break;
      }
    }
    if (!found) new_entries.push(new_entry);

    var that = this;
    return pAddZone(this.props.source, this.props.name, new_entries, this.props.nentry.weight)
      .then(function (json) {
        if (json.result === "success") that.props.onChange();
        return json;
      });
  }

  render() {
    return (
      <>
        <Card>
          <Card.Header as="h5">{this.props.name}</Card.Header>
          <Card.Body>
            {this.state.error &&
                <Alert variant="danger">{this.state.error}</Alert>}
            <div className="float-right">
              <ZoneEntryForm title="Add entry"
                variant="success"
                actionText="Add entry"
                changeFn={this.change.bind(this)} />
              &nbsp;
              <Confirm title="Are you sure?"
                text="Do you really want to delete this zone? The secret key will be lost!"
                variant="danger"
                actionText="Delete zone"
                onConfirm={this.deleteZone.bind(this)} />
            </div>
            <Card.Text>
              <strong>Public key:</strong> {this.props.nentry.pk}
            </Card.Text>
            <Card.Text>
              <strong>Zone version:</strong> {this.props.zentry.version}
            </Card.Text>
            {this.props.zentry.entries.length === 0 ? <p>No entries</p> :
              <Table striped bordered hover>
                <thead>
                <tr>
                    <th>Domain Name</th>
                    <th>Type</th>
                    <th>Value</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {this.props.zentry.entries.map((item)=>
                      <ZoneEntry key={item.join(" ")} item={item}
                        changeFn={this.change.bind(this)}
                        onDelete={this.deleteEntry.bind(this, item)} />
                  )}
                </tbody>
              </Table>
            }
          </Card.Body>
        </Card>
        <br />
      </>
    );
  }
}

function ZoneEntry(props) {
  var name = props.item[0];
  var type = props.item[1];
  var priority = (type === "MX" ? props.item[2] : null);
  var value = (type === "MX" ? props.item[3] : props.item.slice(2).join(" "));
  return (
    <tr>
      <td>
        {name}
      </td>
      <td>{type}</td>
      <td>{props.item.slice(2).join(" ")}</td>
      <td>
        <ZoneEntryForm title="Edit entry"
          variant="primary" actionText="Edit"
          replaces={props.item}
          name={name} type={type} priority={priority} value={value}
          changeFn={props.changeFn} />
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

class ZoneEntryForm extends Component {
  constructor(props, context) {
    super(props, context);

    this.state = {
      show: false,
      err: null,
      name: props.name || "",
      type: props.type || "AAAA",
      priority: props.priority || "5",
      value: props.value || "",
    };
  }

  handleClose(retval) {
    if (retval) {
      var that = this;
      this.props.changeFn(this.props.replaces, this.state)
      .then(function (json) {
        if (json.result === "success") {
          that.setState({ show: false });
        } else {
          that.setState({error: json.reason});
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
            {this.state.error &&
                <Alert variant="danger">{this.state.error}</Alert>}
            <Form>
              <Form.Group controlId="formName">
                <Form.Label>Domain Name</Form.Label>
                <Form.Control name="name" onChange={this.handleInputChange.bind(this)}
                    type="text" placeholder="Name" value={this.state.name} />
              </Form.Group>
              <Form.Group controlId="formType">
                <Form.Label>Type</Form.Label>
                <Form.Control as="select" name="type" onChange={this.handleInputChange.bind(this)}
                  value={this.state.type}>
                  <option>A</option>
                  <option>AAAA</option>
                  <option>CNAME</option>
                  <option>MX</option>
                  <option>TXT</option>
                </Form.Control>
              </Form.Group>
              {this.state.type === "MX" && 
                <Form.Group controlId="formPrio">
                  <Form.Label>Priority</Form.Label>
                  <Form.Control type="text" name="priority" onChange={this.handleInputChange.bind(this)}
                    placeholder="1" value={this.state.priority} />
                </Form.Group>}
              <Form.Group controlId="formName">
                <Form.Label>Value</Form.Label>
                <Form.Control name="value" onChange={this.handleInputChange.bind(this)}
                    type="text" placeholder="Value" value={this.state.value} />
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

export default ZoneEditor;

// vim: set sts=2 ts=2 sw=2 tw=0 et :
