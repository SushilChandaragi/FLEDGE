const crypto = require('crypto');
const config = require('../config/env');
const { HttpError } = require('../utils/HttpError');

// Shared-secret guard for the Google Apps Script -> backend call.
function requireSyncSecret(req, _res, next) {
  const provided = Buffer.from(req.get('x-sync-secret') || '');
  const expected = Buffer.from(config.syncSecret);
  const ok = provided.length === expected.length && crypto.timingSafeEqual(provided, expected);
  if (!ok) return next(new HttpError(401, 'sync_unauthorized', 'Invalid sync credentials.'));
  return next();
}

module.exports = { requireSyncSecret };
