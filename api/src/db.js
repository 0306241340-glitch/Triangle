// Khởi tạo Firebase Admin SDK (1 lần). Dùng serviceAccountKey.json khi chạy local,
// hoặc Application Default Credentials khi chạy trên Cloud Functions.
const admin = require('firebase-admin');

let app;
function getApp() {
  if (!app) {
    try {
      // eslint-disable-next-line global-require
      const serviceAccount = require('../serviceAccountKey.json');
      app = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    } catch (e) {
      app = admin.initializeApp();
    }
  }
  return app;
}

function getDb() { return getApp().firestore(); }
function getAuth() { return getApp().auth(); }

module.exports = { getDb, getAuth, admin };
