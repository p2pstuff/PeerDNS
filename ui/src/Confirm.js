import React, { Component } from 'react';
import { Modal, Button } from 'react-bootstrap';

class Confirm extends Component {
  constructor(props, context) {
    super(props, context);

    this.state = { show: false };
  }

  handleClose(retval) {
    this.setState({ show: false });
    if (retval)
      this.props.onConfirm();
  }

  handleOpen() {
    this.setState({ show: true });
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
          <Modal.Body>{this.props.text}</Modal.Body>
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

export default Confirm;
