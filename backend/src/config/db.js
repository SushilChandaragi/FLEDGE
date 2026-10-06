const mongoose = require('mongoose');
const config = require('./env');

async function connectDb() {
  mongoose.set('strictQuery', true);
  await mongoose.connect(config.mongoUri, {
    dbName: config.mongoDb,
    serverSelectionTimeoutMS: 10000,
  });
  // Make sure unique indexes (participants.srn, attendance eventId+srn) exist
  // before we accept traffic. Duplicate protection depends on them.
  await Promise.all(Object.values(mongoose.models).map((m) => m.init()));
}

module.exports = { connectDb };
