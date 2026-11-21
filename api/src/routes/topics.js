// Route chủ đề + bộ đề: GET /topics, GET /quiz-sets, GET /quiz-sets/:id
const express = require('express');
const { getDb } = require('../db');

const router = express.Router();

router.get('/', async (req, res) => {
  const snap = await getDb().collection('topics').where('isActive', '==', true).get();
  return res.ok(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
});

module.exports = router;
