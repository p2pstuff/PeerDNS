import React, { Component } from 'react';
import ReactDOM from 'react-dom';

import { Nav, Navbar, Container } from 'react-bootstrap';
import { HashRouter as Router, Switch, Route } from 'react-router-dom';
import { LinkContainer } from 'react-router-bootstrap';

import HostEntry from './HostEntry';
import Home from './Home';
import List from './List';
import Zone from './Zone';
import Source from './Source';
import Neighbors from './Neighbors';
import PeerList from './PeerList';

import { isPrivileged, pListPrivileged } from './api';

class App extends Component {
  changeServer() {
    ReactDOM.render(<HostEntry server={this.props.server} />, document.getElementById('root'));
  }

  render() {
    return (
      <Router>
        <div>
          <Navbar bg="dark" variant="dark" expand="lg">
            <LinkContainer to="/">
              <Navbar.Brand>PeerDNS</Navbar.Brand>
            </LinkContainer>
            <Navbar.Collapse id="responsive-navbar-nav">
              <Nav className="mr-auto">
                <LinkContainer to="/list">
                  <Nav.Link>Browse</Nav.Link>
                </LinkContainer>
                { isPrivileged() ?  <PrivilegedLinks /> : <></>}
              </Nav>
              { this.props.offsite &&
                <Nav>
                  <Nav.Link onClick={this.changeServer.bind(this)}>[{this.props.server}]</Nav.Link>
                </Nav>
              }
            </Navbar.Collapse>
          </Navbar>
          <Container>
            <div className="maincontainer">
              <Switch>
                <Route exact path="/" component={Home} />
                <Route exact path="/list" component={List} />
                <Route exact path="/neighbors" component={Neighbors} />
                <Route exact path="/peer_list/:id" render={(props) => (
                    <PeerList key={props.match.params.id} {...props} />
                  )} />
                <Route path="/zone/:name/:pk" render={(props) => (
                    <Zone key={props.match.params.pk} {...props} />
                  )} />
                <Route path="/source/:id" render={(props) => (
                    <Source key={props.match.params.id} {...props} />
                  )} />
              </Switch>
            </div>
          </Container>
        </div>
      </Router>
    );
  }
}

class PrivilegedLinks extends Component {
  constructor() {
    super();
    this.state = { data: null };
  }

  componentDidMount() {
    pListPrivileged()
    .then(json => this.setState({ data: json }));
  }

  render() {
    if (this.state.data == null) {
      return (
        <></>
      );
    } else {
      var sources = this.state.data.sources;
      var peer_lists = this.state.data.peer_lists;
      return (
        <>
          <LinkContainer to={"/neighbors"}>
            <Nav.Link>Neighbors</Nav.Link>
          </LinkContainer>
          {Object.keys(sources).map((k) => (
            <LinkContainer key={k} to={"/source/" + k}>
              <Nav.Link>{sources[k].name}</Nav.Link>
            </LinkContainer>
          ))}
          {Object.keys(peer_lists).map((k) => (
            <LinkContainer key={k} to={"/peer_list/" + k}>
              <Nav.Link>{peer_lists[k].name}</Nav.Link>
            </LinkContainer>
          ))}
        </>
      );
    }
  }
}

export default App

// vim: set sts=2 ts=2 sw=2 tw=0 et :
