const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Operator = require('../models/Operator');
const config = require('../config/env');
const { HttpError } = require('../utils/HttpError');

// Compared against when the operator does not exist, so response time is similar.
const DUMMY_HASH = bcrypt.hashSync('not-a-real-password', 10);

async function login(operatorId, password) {
  const operator = await Operator.findOne({ operatorId: operatorId.trim().toLowerCase(), active: true });
  const ok = await bcrypt.compare(password, operator ? operator.passwordHash : DUMMY_HASH);
  if (!operator || !ok) {
    throw new HttpError(401, 'invalid_credentials', 'Incorrect operator ID or password.');
  }
  const token = jwt.sign({ role: operator.role }, config.jwtSecret, {
    subject: operator.operatorId,
    expiresIn: config.jwtExpiresIn,
  });
  return {
    token,
    operator: { operatorId: operator.operatorId, displayName: operator.displayName, role: operator.role },
  };
}

module.exports = { login };
