const mongoose = require('mongoose');

const eventSchema = new mongoose.Schema(
  {
    eventId: { type: String, required: true, unique: true, trim: true },
    eventName: { type: String, required: true },
    description: { type: String, default: '' },
    date: { type: String, required: true }, // YYYY-MM-DD (IST)
    time: { type: String, required: true }, // HH:mm (IST)
    venue: { type: String, required: true },
    registrationFormUrl: { type: String, default: '' },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

// Registrations that arrive after this moment are classified as walk-ins.
eventSchema.methods.startsAt = function startsAt() {
  return new Date(`${this.date}T${this.time}:00+05:30`);
};

module.exports = mongoose.model('Event', eventSchema);
