const app = require('./app');
const config = require('./config/env');
const { connectDb } = require('./config/db');
require('./models/Event');
require('./models/Participant');
require('./models/Attendance');
require('./models/Operator');

async function main() {
  await connectDb();
  app.listen(config.port, () => {
    console.log(`FLEDGE attendance API listening on :${config.port} (${config.nodeEnv})`);
  });
}

main().catch((err) => {
  console.error('Failed to start server:', err.message);
  process.exit(1);
});
