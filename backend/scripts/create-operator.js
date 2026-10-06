// Usage: npm run operator:create -- <operatorId> <password> ["Display Name"] [role]
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { connectDb } = require('../src/config/db');
const Operator = require('../src/models/Operator');

(async () => {
  const [operatorId, password, displayName = '', role = 'attendance_operator'] = process.argv.slice(2);
  if (!operatorId || !password) {
    console.error('Usage: npm run operator:create -- <operatorId> <password> ["Display Name"] [attendance_operator|admin]');
    process.exit(1);
  }
  if (password.length < 8) {
    console.error('Password must be at least 8 characters.');
    process.exit(1);
  }
  if (!['attendance_operator', 'admin'].includes(role)) {
    console.error('Role must be attendance_operator or admin.');
    process.exit(1);
  }
  await connectDb();
  const passwordHash = await bcrypt.hash(password, 10);
  await Operator.findOneAndUpdate(
    { operatorId: operatorId.toLowerCase() },
    { $set: { passwordHash, displayName, role, active: true } },
    { upsert: true, setDefaultsOnInsert: true }
  );
  console.log(`Operator "${operatorId.toLowerCase()}" saved with role ${role}.`);
  await mongoose.disconnect();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
