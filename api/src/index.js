// WebAPI — App Đố Vui Trắc Nghiệm
// Express chạy trên Firebase Cloud Functions (Gen 2, region asia-southeast1).
// App Flutter chỉ gọi API này, không gọi Firestore trực tiếp.
const express = require('express');
const cors = require('cors');
const { requireAuth, requireAdmin } = require('./auth');
const quizRoutes = require('./routes/quiz');
const topicRoutes = require('./routes/topics');
const quizSetRoutes = require('./routes/quizSets');
const storeRoutes = require('./routes/store');

const app = express();
app.use(cors());
app.use(express.json());

// Trả về chung: { ok: true, data } hoặc { ok: false, error: { code, message } }
app.use((req, res, next) => {
  res.ok = (data) => res.json({ ok: true, data });
  res.fail = (status, code, message) => res.status(status).json({ ok: false, error: { code, message } });
  next();
});

app.get('/health', (req, res) => res.ok({ status: 'ok', time: new Date().toISOString() }));

// Mọi route dưới đây đều cần token (trừ /health).
app.use(requireAuth);
app.use('/topics', topicRoutes);
app.use('/quiz-sets', quizSetRoutes);
app.use('/quiz', quizRoutes);
app.use('/store', storeRoutes);

// Ví dụ route Admin: chỉ role=admin mới vào được.
// app.use('/admin', requireAdmin, require('./routes/admin'));

app.use((req, res) => res.fail(404, 'NOT_FOUND', 'Không tìm thấy endpoint này.'));

// Chạy local: node src/index.js (cần serviceAccountKey.json hoặc GOOGLE_APPLICATION_CREDENTIALS)
if (require.main === module) {
  const port = process.env.PORT || 3000;
<<<<<<< HEAD
  app.listen(port, () => console.log(`API chạy ở http://localhost:${port}`));
} else {
  const functions = require('firebase-functions');
  exports.api = functions.region('asia-southeast1').https.onRequest(app);
=======
  app.listen(port, '0.0.0.0', () => console.log(`API chạy ở http://localhost:${port}`));
>>>>>>> dev
}
