// Creates (or updates) the FLEDGE '26 event and makes sure all indexes exist.
// Usage: npm run seed:event
const mongoose = require('mongoose');
const config = require('../src/config/env');
const { connectDb } = require('../src/config/db');
const Event = require('../src/models/Event');
require('../src/models/Participant');
require('../src/models/Attendance');
require('../src/models/Operator');

(async () => {
  await connectDb();
  const event = await Event.findOneAndUpdate(
    { eventId: config.eventId },
    {
      $set: {
        eventName: "FLEDGE '26",
        description: 'CNEST TBI 2.0 Orientation Programme',
        date: '2026-10-08',
        time: '09:30',
        venue: 'KLE Tech Auditorium, Belagavi',
        registrationFormUrl: config.registrationFormUrl,
        active: true,
      },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  console.log(`Event ready: ${event.eventId} (${event.date} ${event.time})`);
  if (!config.registrationFormUrl || config.registrationFormUrl.includes('REPLACE_ME')) {
    console.warn('WARNING: REGISTRATION_FORM_URL is not set. The registration QR will not work until you set it and re-run.');
  }
  await mongoose.disconnect();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
