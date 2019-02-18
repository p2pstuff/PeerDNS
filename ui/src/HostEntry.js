import React, { Component } from 'react';
import ReactDOM from 'react-dom';

import { Form, Modal, Button } from 'react-bootstrap';

import App from './App';
import { initOffsite } from './api';

class HostEntry extends Component {
  constructor(props) {
    super(props);

    this.state = {
      connecting: false,
      server: this.props.server || "http://localhost:14123/"
    };
  }

  connect() {
    this.setState({connecting: true});
    initOffsite(this.state.server)
    .then(() =>
      ReactDOM.render(<App offsite server={this.state.server} />, document.getElementById('root'))
    );
  }

  submit(event) {
    this.connect();
    event.preventDefault();
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
        <Modal show={true}>
          <Modal.Header>
            <Modal.Title>Enter PeerDNS server URL</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <Form onSubmit={this.submit.bind(this)}>
              <Form.Group controlId="formServerj">
                <Form.Label>PeerDNS API server</Form.Label>
                <Form.Control name="server" onChange={this.handleInputChange.bind(this)}
                    type="text" placeholder="http://localhost:14123/" value={this.state.server} />
              </Form.Group>
            </Form>
          </Modal.Body>
          <Modal.Footer>
            <Button variant="primary" onClick={this.connect.bind(this)}>
              Connect
            </Button>
          </Modal.Footer>
        </Modal>
      </>
    );
    
  }
}

export default HostEntry;
