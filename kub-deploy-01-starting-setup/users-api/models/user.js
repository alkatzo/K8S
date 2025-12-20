const db = require('../db');

class User {
  constructor({ id = null, email, password }) {
    this.id = id;
    this.email = email;
    this.password = password;
  }

  static async findOne(filter) {
    if (!filter || !filter.email) return null;
    const text = 'SELECT id, email, password FROM users WHERE email = $1 LIMIT 1';
    const values = [filter.email];
    const res = await db.pool.query(text, values);
    if (res.rows.length === 0) return null;
    const row = res.rows[0];
    return new User({ id: row.id, email: row.email, password: row.password });
  }

  async save() {
    if (this.id) {
      const text = 'UPDATE users SET email = $1, password = $2 WHERE id = $3 RETURNING id, email, password';
      const values = [this.email, this.password, this.id];
      const res = await db.pool.query(text, values);
      const row = res.rows[0];
      this.id = row.id;
      this.email = row.email;
      this.password = row.password;
      return this;
    }

    const text = 'INSERT INTO users(email, password) VALUES($1, $2) RETURNING id, email, password';
    const values = [this.email, this.password];
    const res = await db.pool.query(text, values);
    const row = res.rows[0];
    this.id = row.id;
    this.email = row.email;
    this.password = row.password;
    return this;
  }

  toObject() {
    return { id: this.id, email: this.email, password: this.password };
  }
}

module.exports = User;
