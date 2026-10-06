const mongoose = require('mongoose');

const participantSchema = new mongoose.Schema(
  {
    srn: { type: String, required: true, unique: true, trim: true, uppercase: true },
    name: { type: String, required: true, trim: true },
    email: { type: String, trim: true, lowercase: true, default: '' },
    branch: { type: String, trim: true, default: '' },
    registration: {
      registered: { type: Boolean, default: true },
      source: {
        type: String,
        enum: ['google_form', 'walk_in_google_form', 'admin_import'],
        default: 'google_form',
      },
      registeredAt: { type: Date, default: Date.now },
    },
  },
  { timestamps: true }
);

// Supports offline snapshot downloads (updatedSince + pagination).
participantSchema.index({ updatedAt: 1, _id: 1 });

module.exports = mongoose.model('Participant', participantSchema);
