// Xác thực: verify Firebase ID token ở header Authorization: Bearer <token>.
// Gắn req.user = { uid, role } để route dùng. Không có token hợp lệ -> 401.
const { getAuth, getDb } = require('./db');

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) return res.fail(401, 'UNAUTHENTICATED', 'Thiếu token đăng nhập.');
  try {
    const decoded = await getAuth().verifyIdToken(token);
    const snap = await getDb().collection('users').doc(decoded.uid).get();
    req.user = { uid: decoded.uid, role: snap.exists ? snap.data().role : 'user' };
    return next();
  } catch (e) {
    return res.fail(401, 'UNAUTHENTICATED', 'Token không hợp lệ hoặc đã hết hạn.');
  }
}

function requireAdmin(req, res, next) {
  if (req.user && req.user.role === 'admin') return next();
  return res.fail(403, 'FORBIDDEN', 'Chỉ quản trị viên mới dùng được chức năng này.');
}

module.exports = { requireAuth, requireAdmin };
