<<<<<<< HEAD
// Khởi tạo Firebase Admin SDK (1 lần). Dùng biến môi trường trên Render,
// serviceAccountKey.json khi chạy local hoặc ADC trên Cloud Functions.
=======
// Khởi tạo Firebase Admin SDK (1 lần). Trên Render đọc key từ biến môi trường
// FIREBASE_SERVICE_ACCOUNT (dán nguyên nội dung file JSON trên 1 dòng),
// khi chạy local vẫn dùng serviceAccountKey.json như cũ.
>>>>>>> dev
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let app;
function getApp() {
  if (!app) {
<<<<<<< HEAD
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const serviceAccountPath = path.join(__dirname, '../serviceAccountKey.json');

    if (serviceAccountJson) {
      let serviceAccount;
      try {
        serviceAccount = JSON.parse(serviceAccountJson);
      } catch (error) {
        throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON must contain valid JSON.', {
          cause: error,
        });
      }
      app = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    } else if (fs.existsSync(serviceAccountPath)) {
      // eslint-disable-next-line global-require, import/no-dynamic-require
      const serviceAccount = require(serviceAccountPath);
      app = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    } else {
      app = admin.initializeApp();
=======
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
>>>>>>> dev
    }
  }
  return app;
}

function getDb() { return getApp().firestore(); }
function getAuth() { return getApp().auth(); }

module.exports = { getDb, getAuth, admin };
