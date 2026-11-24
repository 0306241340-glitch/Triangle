const admin = require('firebase-admin');
const seed = require('./seed-data.json');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();
function toTs(v) { return v ? admin.firestore.Timestamp.fromDate(new Date(v)) : null; }
async function run() {
  for (const t of seed.topics) await db.collection('topics').doc(t.id).set({ ...t, createdAt: toTs(t.createdAt) });
  for (const q of seed.questions) await db.collection('questions').doc(q.id).set({ ...q, createdAt: toTs(q.createdAt) });
  for (const s of seed.quiz_sets) await db.collection('quiz_sets').doc(s.id).set({ ...s, createdAt: toTs(s.createdAt) });
  for (const i of seed.items) await db.collection('items').doc(i.id).set(i);
  for (const u of seed.users) await db.collection('users').doc(u.uid).set({ ...u, createdAt: toTs(u.createdAt), updatedAt: toTs(u.updatedAt) });
  console.log('Import xong: 3 topics, 30 questions, 3 quiz_sets, 8 items, 2 users');
}
run().catch(e => { console.error(e); process.exit(1); });
