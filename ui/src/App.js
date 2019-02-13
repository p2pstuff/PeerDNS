import React, { Component } from 'react';

import { Nav, Navbar, Container } from 'react-bootstrap';
import { HashRouter as Router, Route } from 'react-router-dom';
import { LinkContainer } from 'react-router-bootstrap';

import Home from './Home';
import List from './List';
import Zone from './Zone';

import { isPrivileged } from './api';

class App extends Component {
  render() {
    return (
      <Router>
        <div>
          <Navbar bg="dark" variant="dark" expand="lg">
            <LinkContainer to="/">
              <Navbar.Brand>PeerDNS</Navbar.Brand>
            </LinkContainer>
            <Nav>
              <LinkContainer to="/list">
                <Nav.Link>Browse</Nav.Link>
              </LinkContainer>
              { isPrivileged() ?
                <>
                  <LinkContainer to="/my">
                    <Nav.Link>My domains</Nav.Link>
                  </LinkContainer>
                </>
              : <></>}
            </Nav>
          </Navbar>
          <Container>
            <div className="maincontainer">
              <Route exact path="/" component={Home} />
              <Route exact path="/list" component={List} />
              <Route path="/zone/:name/:pk" component={Zone} />
            </div>
          </Container>
        </div>
      </Router>
    );
  }
}

export default App

// vim: set sts=2 ts=2 sw=2 tw=0 et :
