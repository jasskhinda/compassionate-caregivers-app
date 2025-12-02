const admin = require('firebase-admin');
const serviceAccount = require('./functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkUser() {
  // Check user 1H9Ua4SbI3aSPQiJKRo5BNPMUrw2 (the recipient from logs)
  const userDoc = await db.collection('users').doc('1H9Ua4SbI3aSPQiJKRo5BNPMUrw2').get();
  if (userDoc.exists) {
    const data = userDoc.data();
    console.log('User:', data.name || data.email);
    console.log('OneSignal Player ID:', data.oneSignalPlayerId || 'NOT SET');
    console.log('FCM Token:', data.fcmToken ? 'SET' : 'NOT SET');
  } else {
    console.log('User not found');
  }
  process.exit(0);
}

checkUser();
