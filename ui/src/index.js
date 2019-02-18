import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import HostEntry from './HostEntry';
import './style.css';

import { init } from './api';

if (process.env.REACT_APP_OFFSITE === "offsite") {
  var server = null;
  window.location.search.substr(1).split("&").forEach(function(item) {
    var tmp = item.split("=");
    if (tmp[0] === "server") {
      server = "http://" + tmp[1] + "/";
    }
  });

  ReactDOM.render(<HostEntry server={server} />, document.getElementById('root'));
} else {
    init()
    .then(() =>
      ReactDOM.render(<App />, document.getElementById('root'))
    );
}
