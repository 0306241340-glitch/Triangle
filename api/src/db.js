// Khởi tạo Firebase Admin SDK (1 lần). Trên Render đọc key từ biến môi trường
// FIREBASE_SERVICE_ACCOUNT (dán nguyên nội dung file JSON trên 1 dòng),
// khi chạy local vẫn dùng serviceAccountKey.json như cũ.
const admin = require('firebase-admin');

let app;
function getApp() {
  if (!app) {
    const envKey = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (envKey) {
      const serviceAccount = JSON.parse(envKey);
      app = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    } else {
      try {
        // eslint-disable-next-line global-require
        const serviceAccount = require('../serviceAccountKey.json');
        app = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      } catch (e) {
        app = admin.initializeApp();
      }
    }
  }
  return app;
}

function getDb() { return getApp().firestore(); }
function getAuth() { return getApp().auth(); }

module.exports = { getDb, getAuth, admin };
