// Cửa hàng: GET /store/items, POST /store/purchase
const express = require('express');
const { getDb, admin } = require('../db');

const router = express.Router();

router.get('/items', async (req, res) => {
  const db = getDb();
  const [itemsSnap, userSnap, inventorySnap] = await Promise.all([
    db.collection('items').where('isActive', '==', true).get(),
    db.collection('users').doc(req.user.uid).get(),
    db.collection('user_items').where('userId', '==', req.user.uid).get(),
  ]);

  if (!userSnap.exists) {
    return res.fail(404, 'NOT_FOUND', 'Không tìm thấy hồ sơ người dùng.');
  }
  const coins = userSnap.data().coins;
  if (!Number.isSafeInteger(coins) || coins < 0) {
    return res.fail(500, 'INVALID_BALANCE', 'Số dư xu trong hồ sơ chưa hợp lệ.');
  }

  const inventory = {};
  inventorySnap.docs.forEach((doc) => {
    const data = doc.data();
    if (data.itemId) {
      const quantity = Number.isSafeInteger(data.quantity) && data.quantity > 0
        ? data.quantity
        : 1;
      inventory[data.itemId] = (inventory[data.itemId] || 0) + quantity;
    }
  });
  const items = itemsSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => {
      const order = { help: 0, frame: 1, title: 2 };
      return (order[a.type] ?? 3) - (order[b.type] ?? 3) || a.price - b.price;
    });

  return res.ok({ coins, items, inventory });
});

router.post('/purchase', async (req, res) => {
  const { itemId } = req.body || {};
  if (typeof itemId !== 'string' || !itemId.trim()) {
    return res.fail(400, 'VALIDATION', 'Thiếu itemId hợp lệ.');
  }

  const normalizedItemId = itemId.trim();
  const db = getDb();
  const itemRef = db.collection('items').doc(normalizedItemId);
  const userRef = db.collection('users').doc(req.user.uid);
  const userItemsQuery = db.collection('user_items')
    .where('userId', '==', req.user.uid);
  const fallbackUserItemRef = db.collection('user_items')
    .doc(`${req.user.uid}_${encodeURIComponent(normalizedItemId)}`);
  const transactionRef = db.collection('transactions').doc();

  const result = await db.runTransaction(async (tx) => {
    const [itemSnap, userSnap, inventorySnap] = await Promise.all([
      tx.get(itemRef),
      tx.get(userRef),
      tx.get(userItemsQuery),
    ]);
    const matchingItems = inventorySnap.docs.filter(
      (doc) => doc.data().itemId === normalizedItemId,
    );
    const preferredItem = matchingItems.find(
      (doc) => doc.id === fallbackUserItemRef.id,
    ) || matchingItems[0];
    const userItemRef = preferredItem
      ? preferredItem.ref
      : fallbackUserItemRef;

    if (!itemSnap.exists || itemSnap.data().isActive !== true) {
      return { status: 404, code: 'NOT_FOUND', message: 'Vật phẩm không tồn tại hoặc đã ngừng bán.' };
    }
    if (!userSnap.exists) {
      return { status: 404, code: 'NOT_FOUND', message: 'Không tìm thấy hồ sơ người dùng.' };
    }

    const item = itemSnap.data();
    const price = item.price;
    if (!Number.isSafeInteger(price) || price < 0) {
      return { status: 500, code: 'INVALID_ITEM', message: 'Giá vật phẩm chưa được cấu hình hợp lệ.' };
    }

    if (matchingItems.length > 0 && item.type !== 'help') {
      return { status: 409, code: 'ALREADY_OWNED', message: 'Bạn đã sở hữu vật phẩm này.' };
    }

    const user = userSnap.data();
    const coins = user.coins;
    if (!Number.isSafeInteger(coins) || coins < 0) {
      return { status: 500, code: 'INVALID_BALANCE', message: 'Số dư xu trong hồ sơ chưa hợp lệ.' };
    }
    if (coins < price) {
      return { status: 409, code: 'INSUFFICIENT_COINS', message: 'Bạn không đủ xu để mua vật phẩm này.' };
    }

    const ownedQuantity = matchingItems.reduce((total, doc) => {
      const data = doc.data();
      const quantity = Number.isSafeInteger(data.quantity) && data.quantity > 0
        ? data.quantity
        : 1;
      return total + quantity;
    }, 0);
    const quantity = ownedQuantity + 1;
    const now = admin.firestore.FieldValue.serverTimestamp();

    tx.update(userRef, {
      coins: coins - price,
      updatedAt: now,
    });
    tx.set(userItemRef, {
      userId: req.user.uid,
      itemId: normalizedItemId,
      quantity,
      equipped: matchingItems.some((doc) => doc.data().equipped === true),
      ...(matchingItems.length === 0 ? { createdAt: now } : {}),
      updatedAt: now,
    }, { merge: true });
    matchingItems.forEach((doc) => {
      if (doc.id !== userItemRef.id) tx.delete(doc.ref);
    });
    tx.set(transactionRef, {
      userId: req.user.uid,
      type: 'purchase',
      amount: price,
      reason: 'shop_purchase',
      relatedId: normalizedItemId,
      createdAt: now,
    });

    return { coins: coins - price, quantity };
  });

  if (result.status) {
    return res.fail(result.status, result.code, result.message);
  }
  return res.ok(result);
});

module.exports = router;
