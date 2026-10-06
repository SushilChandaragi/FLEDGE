const Participant = require('../models/Participant');
const { normalizeSrn, isValidSrn } = require('../utils/srn');
const { HttpError } = require('../utils/HttpError');

function toPublic(p) {
  return {
    srn: p.srn,
    name: p.name,
    email: p.email,
    branch: p.branch,
    registered: p.registration.registered,
    registrationSource: p.registration.source,
    registeredAt: p.registration.registeredAt,
  };
}

async function findBySrn(rawSrn) {
  const srn = normalizeSrn(rawSrn);
  if (!isValidSrn(srn)) throw new HttpError(400, 'invalid_srn', 'That SRN does not look valid.');
  const participant = await Participant.findOne({ srn, 'registration.registered': true }).lean();
  return { srn, participant };
}

/**
 * Read-only snapshot for offline lookup. Cursor pagination on (updatedAt, _id)
 * so devices can pull everything, then only deltas afterwards.
 */
async function snapshot({ updatedSince, afterId, limit }) {
  const filter = { 'registration.registered': true };
  if (updatedSince) {
    filter.$or = [{ updatedAt: { $gt: updatedSince } }];
    if (afterId) filter.$or.push({ updatedAt: updatedSince, _id: { $gt: afterId } });
  }
  const rows = await Participant.find(filter).sort({ updatedAt: 1, _id: 1 }).limit(limit + 1).lean();
  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  const last = page[page.length - 1];
  return {
    participants: page.map((p) => ({
      srn: p.srn,
      name: p.name,
      branch: p.branch,
      registrationSource: p.registration.source,
      registeredAt: p.registration.registeredAt,
    })),
    hasMore,
    next: last ? { updatedSince: last.updatedAt, afterId: String(last._id) } : null,
  };
}

/** Upsert by SRN. Re-submitting the form updates details but keeps first registeredAt. */
async function upsertRegistration({ srn, name, email, branch, source, registeredAt }) {
  const normalized = normalizeSrn(srn);
  if (!isValidSrn(normalized)) throw new HttpError(400, 'invalid_srn', 'Invalid SRN.');
  const doc = await Participant.findOneAndUpdate(
    { srn: normalized },
    {
      $set: {
        name: name.trim(),
        email: (email || '').trim().toLowerCase(),
        branch: (branch || '').trim().toUpperCase(),
        'registration.registered': true,
      },
      $setOnInsert: {
        srn: normalized,
        'registration.source': source || 'google_form',
        'registration.registeredAt': registeredAt || new Date(),
      },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true, includeResultMetadata: true }
  );
  return { participant: doc.value, created: !doc.lastErrorObject.updatedExisting };
}

async function listParticipants({ page = 1, limit = 50, search = '' }) {
  const filter = { 'registration.registered': true };
  if (search && search.trim()) {
    const s = search.trim();
    filter.$or = [
      { srn: { $regex: s, $options: 'i' } },
      { name: { $regex: s, $options: 'i' } },
      { branch: { $regex: s, $options: 'i' } },
    ];
  }
  const skip = (page - 1) * limit;
  const [total, rows] = await Promise.all([
    Participant.countDocuments(filter),
    Participant.find(filter)
      .sort({ 'registration.registeredAt': -1, srn: 1 })
      .skip(skip)
      .limit(limit)
      .lean(),
  ]);
  return {
    total,
    page,
    limit,
    hasMore: skip + rows.length < total,
    items: rows.map((p) => ({
      srn: p.srn,
      name: p.name,
      email: p.email,
      branch: p.branch,
      registrationSource: p.registration.source,
      registeredAt: p.registration.registeredAt,
    })),
  };
}

module.exports = { findBySrn, snapshot, listParticipants, upsertRegistration, toPublic };
