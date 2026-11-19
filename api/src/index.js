
const express = require('express');
const cors = require('cors');
const functions = require('firebase-functions');

const { requireAuth, requireAdmin } = require('./auth');
const quizRoutes = require('./routes/quiz');
const topicRoutes = require('./routes/topics');
const quizSetRoutes = require('./routes/quizSets');
const storeRoutes = require('./routes/store');

const app = express();

app.use(cors());
app.use(express.json());

// Tra ve chung: { ok: true, data } hoac { ok: false, error }
app.use((req, res, next) => {
  res.ok = (data) => res.json({ ok: true, data });
  res.fail = (status, code, message) =>
    res.status(status).json({
      ok: false,
      error: { code, message },
    });
  next();
});

app.get('/health', (req, res) =>
  res.ok({ status: 'ok', time: new Date().toISOString() }),
);

// Cac route duoi day deu can token, tru /health.
app.use(requireAuth);
app.use('/topics', topicRoutes);
app.use('/quiz-sets', quizSetRoutes);
app.use('/quiz', quizRoutes);
app.use('/store', storeRoutes);

// Route Admin: chi role=admin moi vao duoc.
// app.use('/admin', requireAdmin, require('./routes/admin'));

app.use((req, res) =>
  res.fail(404, 'NOT_FOUND', 'Khong tim thay endpoint nay.'),
);

// Chay local: node src/index.js
if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, '0.0.0.0', () =>
    console.log(`API chay o http://localhost:${port}`),
  );
}

// Firebase Cloud Functions
exports.api = functions.region('asia-southeast1').https.onRequest(app);

module.exports = app;
