import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import './style.css';

import { init } from './api';

init()
.then(() =>
  ReactDOM.render(<App />, document.getElementById('root'))
);
