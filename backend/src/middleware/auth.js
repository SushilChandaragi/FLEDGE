const jwt = require('jsonwebtoken');
const config = require('../config/env');
const { HttpError } = require('../utils/HttpError');

function authenticate(req, _res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'auth_required', 'Please sign in to continue.'));
  }
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.operator = { operatorId: payload.sub, role: payload.role };
    return next();
  } catch (err) {
    const code = err.name === 'TokenExpiredError' ? 'token_expired' : 'auth_invalid';
    return next(new HttpError(401, code, 'Your session has expired. Please sign in again.'));
  }
}

function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.operator || !roles.includes(req.operator.role)) {
      return next(new HttpError(403, 'forbidden', 'You do not have access to this action.'));
    }
    return next();
  };
}

module.exports = { authenticate, requireRole };
