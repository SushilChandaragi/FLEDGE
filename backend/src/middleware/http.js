const { ZodError } = require('zod');
const { HttpError } = require('../utils/HttpError');

function validate(schema, source = 'body') {
  return (req, _res, next) => {
    const parsed = schema.safeParse(req[source]);
    if (!parsed.success) {
      return next(new HttpError(400, 'validation_error', parsed.error.issues[0]?.message || 'Invalid request.'));
    }
    req[source] = parsed.data;
    return next();
  };
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, _next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ success: false, status: err.code, message: err.message });
  }
  if (err instanceof ZodError) {
    return res.status(400).json({ success: false, status: 'validation_error', message: 'Invalid request.' });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ success: false, status: 'validation_error', message: 'Malformed JSON.' });
  }
  console.error('[error]', req.method, req.originalUrl, err);
  return res
    .status(500)
    .json({ success: false, status: 'server_error', message: 'Something went wrong. Please try again.' });
}

function notFound(_req, res) {
  res.status(404).json({ success: false, status: 'not_found', message: 'Route not found.' });
}

module.exports = { validate, errorHandler, notFound };
