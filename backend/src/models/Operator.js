const mongoose = require('mongoose');

const operatorSchema = new mongoose.Schema(
  {
    operatorId: { type: String, required: true, unique: true, trim: true, lowercase: true },
    displayName: { type: String, default: '' },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ['attendance_operator', 'admin'], default: 'attendance_operator' },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Operator', operatorSchema);
