// Bulk-load registrations from a CSV exported from the Google Sheet.
// Usage: npm run import:csv -- path/to/responses.csv
// Accepted headers (case-insensitive): srn, name|full name, email, branch
const fs = require('fs');
const mongoose = require('mongoose');
const { connectDb } = require('../src/config/db');
require('../src/models/Participant');
const { upsertRegistration } = require('../src/services/participantService');

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i += 1; }
      else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i += 1;
      row.push(cell); cell = '';
      if (row.some((c) => c.trim())) rows.push(row);
      row = [];
    } else cell += ch;
  }
  if (cell || row.length) { row.push(cell); if (row.some((c) => c.trim())) rows.push(row); }
  return rows;
}

(async () => {
  const file = process.argv[2];
  if (!file) { console.error('Usage: npm run import:csv -- <file.csv>'); process.exit(1); }
  const rows = parseCsv(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  const header = rows.shift().map((h) => h.trim().toLowerCase());
  const col = (...names) => header.findIndex((h) => names.some((n) => h.includes(n)));
  const idx = { srn: col('srn'), name: col('full name', 'name'), email: col('email'), branch: col('branch') };
  if (idx.srn < 0 || idx.name < 0) { console.error('CSV needs SRN and Name columns.'); process.exit(1); }

  await connectDb();
  let created = 0; let updated = 0; let rejected = 0;
  for (const r of rows) {
    try {
      const { created: isNew } = await upsertRegistration({
        srn: r[idx.srn] || '',
        name: r[idx.name] || '',
        email: idx.email >= 0 ? r[idx.email] : '',
        branch: idx.branch >= 0 ? r[idx.branch] : '',
        source: 'admin_import',
      });
      if (isNew) created += 1; else updated += 1;
    } catch (e) {
      rejected += 1;
      console.warn(`Skipped "${r[idx.srn]}": ${e.message}`);
    }
  }
  console.log(`Import done. created=${created} updated=${updated} rejected=${rejected}`);
  await mongoose.disconnect();
})().catch((e) => { console.error(e.message); process.exit(1); });
