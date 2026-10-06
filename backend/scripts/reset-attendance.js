// Usage: npm run reset:attendance
const readline = require('readline');
const mongoose = require('mongoose');
const { connectDb } = require('../src/config/db');
const Attendance = require('../src/models/Attendance');
const config = require('../src/config/env');

async function main() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  rl.question(`WARNING: This will delete all attendance records for event ${config.eventId} in database "${config.mongoDb}".\nType YES to confirm: `, async (answer) => {
    rl.close();
    if (answer.trim() !== 'YES') {
      console.log('Aborted. No records deleted.');
      process.exit(0);
    }
    await connectDb();
    const result = await Attendance.deleteMany({ eventId: config.eventId.toUpperCase() });
    console.log(`Successfully deleted ${result.deletedCount} attendance record(s) for event ${config.eventId}.`);
    await mongoose.disconnect();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
