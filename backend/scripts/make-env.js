// One-off helper: builds backend/.env from the Atlas credentials file + fresh random secrets.
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const atlas = fs.readFileSync(path.join(__dirname, '..', '..', 'atlas-credentials (1).env'), 'utf8');
const uri = atlas.match(/^MONGODB_URI="(.*)"/m)[1];
const out = fs
  .readFileSync(path.join(__dirname, '..', '.env.example'), 'utf8')
  .replace(/^MONGODB_URI=.*/m, `MONGODB_URI=${uri}`)
  .replace(/^JWT_SECRET=.*/m, `JWT_SECRET=${crypto.randomBytes(48).toString('hex')}`)
  .replace(/^REGISTRATION_SYNC_SECRET=.*/m, `REGISTRATION_SYNC_SECRET=${crypto.randomBytes(24).toString('hex')}`);
fs.writeFileSync(path.join(__dirname, '..', '.env'), out);
console.log('backend/.env written');
