const mongoose = require('mongoose');

// Name/branch are copied at scan time so the records list can search and
// render without joins. Attendance rows are append-only: no update/delete API.
const attendanceSchema = new mongoose.Schema(
  {
    eventId: { type: String, required: true },
    srn: { type: String, required: true, uppercase: true },
    name: { type: String, required: true },
    branch: { type: String, default: '' },
    attendanceStatus: { type: String, enum: ['present'], default: 'present' },
    registrationStatus: { type: String, enum: ['pre_registered', 'walk_in'], required: true },
    scannedAt: { type: Date, required: true }, // when the student was scanned (device clock, clamped)
    receivedAt: { type: Date, default: Date.now }, // when the server stored it
    deviceId: { type: String, required: true },
    operatorId: { type: String, required: true },
    offlineSync: { type: Boolean, default: false },
  },
  { timestamps: false }
);

// Global duplicate protection across every device.
attendanceSchema.index({ eventId: 1, srn: 1 }, { unique: true });
attendanceSchema.index({ eventId: 1, scannedAt: -1 });
attendanceSchema.index({ eventId: 1, registrationStatus: 1 });

module.exports = mongoose.model('Attendance', attendanceSchema);
