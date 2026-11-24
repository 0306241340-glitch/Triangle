// Xóa chủ đề + bộ đề + câu hỏi CŨ khỏi Firestore,
// sau khi đã đổi seed sang 3 chủ đề mới. Chạy 1 lần duy nhất, TRƯỚC khi import seed mới.
// Cách chạy (trong thư mục firebase, đã có serviceAccountKey.json + firebase-admin@12):
//   node xoa-chu-de-cu.js
//   node import-seed.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Chủ đề/bộ đề cũ: 3 chủ đề Toán / Lịch sử VN / Khoa học
// (+ Văn hóa, phòng trường hợp đã lỡ import file seed 4 chủ đề).
const OLD_TOPICS = ['topic_math', 'topic_history', 'topic_science', 'topic_van_hoa'];
const OLD_SETS = ['set_math_1', 'set_history_1', 'set_science_1', 'set_van_hoa_1'];

async function run() {
  let t = 0;
  for (const id of OLD_TOPICS) {
    const snap = await db.collection('topics').doc(id).get();
    if (snap.exists) {
      await db.collection('topics').doc(id).delete();
      t++;
    }
  }
  let s = 0;
  for (const id of OLD_SETS) {
    const snap = await db.collection('quiz_sets').doc(id).get();
    if (snap.exists) {
      await db.collection('quiz_sets').doc(id).delete();
      s++;
    }
  }
  const qSnap = await db.collection('questions').get();
  let n = 0;
  for (const doc of qSnap.docs) {
    if (OLD_TOPICS.includes(doc.data().topicId)) {
      await doc.ref.delete();
      n++;
    }
  }
  console.log(`Đã xóa: ${t} chủ đề cũ, ${s} bộ đề cũ, ${n} câu hỏi cũ.`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
