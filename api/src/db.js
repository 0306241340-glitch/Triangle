
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let app;

function getApp() {
  if (!app) {
    // Ho tro ca hai ten bien moi truong.
    const serviceAccountJson =
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
      process.env.FIREBASE_SERVICE_ACCOUNT;

    const serviceAccountPath = path.join(
      __dirname,
      '../serviceAccountKey.json',
    );

    if (serviceAccountJson) {
      let serviceAccount;

      try {
        serviceAccount = JSON.parse(serviceAccountJson);
      } catch (error) {
        throw new Error(
          'Firebase service account environment variable must contain valid JSON.',
          { cause: error },
        );
      }

      app = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);

      app = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } else {
      // Dung Application Default Credentials tren Firebase Cloud Functions.
      app = admin.initializeApp();
    }
  }

  return app;
}

function getDb() {
  return getApp().firestore();
}

function getAuth() {
  return getApp().auth();
}

module.exports = { getDb, getAuth, admin };
