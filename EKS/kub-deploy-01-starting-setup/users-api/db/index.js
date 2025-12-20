const { Pool } = require('pg');

const connectionString = process.env.POSTGRES_CONNECTION_URI;

if (!connectionString) {
  console.warn('POSTGRES_CONNECTION_URI not set. DB connections will fail until it is provided.');
}

const pool = new Pool({ connectionString });

async function init() {
  // create users table if it doesn't exist
  const createTable = `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL
    );
  `;
  await pool.query(createTable);
}

module.exports = { pool, init };
