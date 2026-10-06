// SRN is treated as an opaque string. We only normalise and sanity check it.
const SRN_PATTERN = /^[A-Z0-9][A-Z0-9\-_/.]{3,29}$/;

function normalizeSrn(raw) {
  if (typeof raw !== 'string') return '';
  return raw.replace(/\s+/g, '').toUpperCase();
}

function isValidSrn(srn) {
  return SRN_PATTERN.test(srn);
}

module.exports = { normalizeSrn, isValidSrn };
