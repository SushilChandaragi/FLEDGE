const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config/env');
const routes = require('./routes');
const { errorHandler, notFound } = require('./middleware/http');

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors(config.corsOrigins.length ? { origin: config.corsOrigins } : {}));
app.use(express.json({ limit: '256kb' }));
app.use('/api', routes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
