import React, { Component } from 'react';

import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Nav from 'react-bootstrap/Nav';

import getNodeInfo from './api';

class App extends Component {
  constructor() {
    super();
    this.state = { data: {} };
  }

  componentDidMount() {
    getNodeInfo()
    .then(json => this.setState({ data: json}));
  }

  render() {
    return (
      <>
        <Navbar bg="dark" variant="dark" expand="lg">
          <Navbar.Brand href="#">PeerDNS</Navbar.Brand>
          <Nav>
            <Nav.Link href="#">Node information</Nav.Link>
            <Nav.Link href="#">My domains</Nav.Link>
            <Nav.Link href="#">Browse domains</Nav.Link>
          </Nav>
        </Navbar>
        <Container>
          <dl>
            {Object.keys(this.state.data).map((k)=>(
              <><dt>{k}</dt><dd>{JSON.stringify(this.state.data[k])}</dd></>
            ))}
          </dl>
        </Container>
      </>
    );
  }
}

export default App;
