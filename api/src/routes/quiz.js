// Route chơi đơn: POST /quiz/start, POST /quiz/submit
// Nguyên tắc: đáp án đúng (correctIndex) không bao giờ rời khỏi server.
// Điểm/xu chỉ cộng ở đây, trong 1 Firestore transaction.
const express = require('express');
const { getDb, admin } = require('../db');

const router = express.Router();
const POINTS = { easy: { score: 10, coins: 5 }, medium: { score: 20, coins: 10 }, hard: { score: 30, coins: 15 } };

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1));[a[i], a[j]] = [a[j], a[i]]; }
  return a;
}

// POST /quiz/start { quizSetId } -> 10 câu đã xáo, KHÔNG có correctIndex
router.post('/start', async (req, res) => {
  const { quizSetId } = req.body || {};
  if (!quizSetId) return res.fail(400, 'VALIDATION', 'Thiếu quizSetId.');
  const db = getDb();
  const setSnap = await db.collection('quiz_sets').doc(quizSetId).get();
  if (!setSnap.exists || !setSnap.data().isActive) return res.fail(404, 'NOT_FOUND', 'Không tìm thấy bộ đề.');
  const set = setSnap.data();
  const qSnap = await db.collection('questions')
    .where('topicId', '==', set.topicId).where('isActive', '==', true).get();
  const all = shuffle(qSnap.docs.map((d) => ({ id: d.id, ...d.data() })));
  const picked = all.slice(0, set.questionCount || 10);
  if (picked.length === 0) return res.fail(400, 'VALIDATION', 'Bộ đề chưa có câu hỏi.');
  const attemptId = `att_${Date.now()}_${req.user.uid.slice(0, 6)}`;
  const questions = picked.map((q) => {
    const order = shuffle([0, 1, 2, 3]);
    return {
      id: q.id,
      content: q.content,
      // Chỉ gửi nội dung + 4 lựa chọn đã xáo, không gửi correctIndex.
      options: order.map((i) => q.options[i]),
      // Vị trí đáp án đúng sau khi xáo, chỉ lưu ở server (ghi vào attempt, không trả về).
      _answerPos: order.indexOf(q.correctIndex),
      level: q.level,
    };
  });
  // Lưu đáp án đúng vào collection attempts (server-only), client không đọc được.
  await db.collection('attempts').doc(attemptId).set({
    userId: req.user.uid, quizSetId, topicId: set.topicId,
    durationSec: set.durationSec || 300,
    answers: questions.map((q) => ({ questionId: q.id, correctIndex: q._answerPos, level: q.level })),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return res.ok({
    attemptId, durationSec: set.durationSec || 300,
    questions: questions.map(({ _answerPos, ...q }) => q),
  });
});

// POST /quiz/submit { attemptId, quizSetId, answers, timeTakenSec }
router.post('/submit', async (req, res) => {
  const { attemptId, quizSetId, answers, timeTakenSec } = req.body || {};
  if (!attemptId || !quizSetId || !Array.isArray(answers)) {
    return res.fail(400, 'VALIDATION', 'Thiếu attemptId, quizSetId hoặc answers.');
  }
  const db = getDb();
  const attemptRef = db.collection('attempts').doc(attemptId);
  const attemptSnap = await attemptRef.get();
  if (!attemptSnap.exists) return res.fail(404, 'NOT_FOUND', 'Không tìm thấy lượt chơi này.');
  if (attemptSnap.data().submitted) {
    // Chống nộp trùng: cùng attemptId chỉ cộng điểm 1 lần.
    return res.fail(409, 'CONFLICT', 'Lượt chơi này đã nộp rồi, không cộng điểm lần 2.');
  }
  const attempt = attemptSnap.data();
  if (attempt.userId !== req.user.uid) return res.fail(403, 'FORBIDDEN', 'Không phải lượt chơi của bạn.');
  const byId = new Map(attempt.answers.map((a) => [a.questionId, a]));
  let score = 0; let coins = 0; let correctCount = 0;
  const details = answers.map((a) => {
    const key = byId.get(a.questionId);
    const isCorrect = !!key && a.selectedIndex === key.correctIndex;
    if (isCorrect) { correctCount += 1; score += POINTS[key.level].score; coins += POINTS[key.level].coins; }
    return { questionId: a.questionId, selectedIndex: a.selectedIndex, correctIndex: key ? key.correctIndex : -1, isCorrect, level: key ? key.level : 'easy' };
  });
  const historyRef = db.collection('quiz_histories').doc();
  await db.runTransaction(async (tx) => {
    const userRef = db.collection('users').doc(req.user.uid);
    const userSnap = await tx.get(userRef);
    const user = userSnap.data();
    const setRef = db.collection('quiz_sets').doc(quizSetId);
    const setSnap = await tx.get(setRef);
    const prevCount = setSnap.data().attemptCount || 0;
    const prevAvg = setSnap.data().avgScore || 0;
    tx.set(historyRef, {
      userId: req.user.uid, quizSetId, topicId: attempt.topicId,
      score, correctCount, totalCount: attempt.answers.length,
      coinsEarned: coins, details, timeTakenSec: timeTakenSec || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(userRef, {
      score: (user.score || 0) + score,
      weeklyScore: (user.weeklyScore || 0) + score,
      monthlyScore: (user.monthlyScore || 0) + score,
      coins: (user.coins || 0) + coins,
    });
    tx.set(db.collection('transactions').doc(), {
      userId: req.user.uid, type: 'earn', amount: coins,
      reason: 'quiz_reward', relatedId: historyRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(attemptRef, { submitted: true });
    tx.update(setRef, {
      attemptCount: prevCount + 1,
      avgScore: Math.round(((prevAvg * prevCount) + score) / (prevCount + 1)),
    });
  });
  return res.ok({ score, correctCount, totalCount: attempt.answers.length, coinsEarned: coins, historyId: historyRef.id });
});

module.exports = router;
