require('dotenv').config();

function required(name) {
  const value = process.env[name];
  if (!value || value.startsWith('change-me')) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const config = {
  port: Number(process.env.PORT) || 4000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: required('MONGODB_URI'),
  mongoDb: process.env.MONGODB_DB || 'cnest_fledge',
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  syncSecret: required('REGISTRATION_SYNC_SECRET'),
  eventId: process.env.EVENT_ID || 'FLEDGE26',
  registrationFormUrl: process.env.REGISTRATION_FORM_URL || '',
  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
};

module.exports = config;
