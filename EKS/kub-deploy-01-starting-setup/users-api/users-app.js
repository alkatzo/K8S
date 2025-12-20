const express = require('express');
const bodyParser = require('body-parser');
const morgan = require('morgan');
const db = require('./db');

const userRoutes = require('./routes/user-routes');

const app = express();

app.use(bodyParser.json());
// HTTP request logging to stdout so `kubectl logs` shows requests
app.use(morgan('combined'));

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

app.use(userRoutes);

app.use((err, req, res, next) => {
  // log the full error to stderr for kubectl logs and debugging
  console.error(err);
  let code = 500;
  let message = 'Something went wrong.';
  if (err.code) {
    code = err.code;
  }

  if (err.message) {
    message = err.message;
  }
  res.status(code).json({ message: message });
});

// initialize Postgres connection and start server
db.init()
  .then(() => {
    console.log('Connected to Postgres, starting server on port 3000');
    app.listen(3000, () => console.log('Users API listening on port 3000'));
  })
  .catch((err) => {
    console.error('COULD NOT CONNECT TO POSTGRES!', err);
  });
