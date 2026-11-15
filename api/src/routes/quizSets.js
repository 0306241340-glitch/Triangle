// Route bộ đề: GET /quiz-sets, GET /quiz-sets/:id
// Có tìm kiếm (search) + lọc (topicId, level) — phiếu mục 11, 12.
const express = require('express');
const { getDb } = require('../db');

const router = express.Router();

router.get('/', async (req, res) => {
  const { topicId, level, search } = req.query;
  let q = getDb().collection('quiz_sets').where('isActive', '==', true);
  if (topicId) q = q.where('topicId', '==', topicId);
  const snap = await q.get();
  let sets = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  if (level) sets = sets.filter((s) => s.difficulty === level);
  if (search) sets = sets.filter((s) => s.name.toLowerCase().includes(String(search).toLowerCase()));
  return res.ok(sets);
});

router.get('/:id', async (req, res) => {
  const snap = await getDb().collection('quiz_sets').doc(req.params.id).get();
  if (!snap.exists) return res.fail(404, 'NOT_FOUND', 'Không tìm thấy bộ đề.');
  const commentsSnap = await getDb().collection('comments')
    .where('quizSetId', '==', req.params.id).orderBy('createdAt', 'desc').limit(20).get();
  return res.ok({
    id: snap.id, ...snap.data(),
    comments: commentsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
  });
});

module.exports = router;
