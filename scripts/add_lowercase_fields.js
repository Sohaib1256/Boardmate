const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  console.log('=== Adding Lowercase Fields for Search ===\n');

  // 1. Process Resources
  const resSnap = await db.collection('resources').get();
  console.log(`Resources: Found ${resSnap.size} documents.`);
  
  let resCount = 0;
  let resBatch = db.batch();
  for (const doc of resSnap.docs) {
    const data = doc.data();
    // Update if lowercase field is missing OR if it doesn't match the current title
    const expectedTitle = data.title ? data.title.toLowerCase() : null;
    const expectedSubject = data.subject ? data.subject.toLowerCase() : null;
    let needsUpdate = false;
    let updateData = {};

    if (expectedTitle && data.title_lowercase !== expectedTitle) {
      updateData.title_lowercase = expectedTitle;
      needsUpdate = true;
    }
    if (expectedSubject && data.subject_lowercase !== expectedSubject) {
      updateData.subject_lowercase = expectedSubject;
      needsUpdate = true;
    }

    if (needsUpdate) {
      resBatch.update(doc.ref, updateData);
      resCount++;
    }
  }
  if (resCount > 0) {
    await resBatch.commit();
    console.log(`Resources: Updated ${resCount} documents.\n`);
  } else {
    console.log('Resources: No updates needed.\n');
  }

  // 2. Process Quizzes
  const quizSnap = await db.collection('quiz_sessions').get();
  console.log(`Quizzes: Found ${quizSnap.size} documents.`);
  
  let quizCount = 0;
  let quizBatch = db.batch();
  for (const doc of quizSnap.docs) {
    const data = doc.data();
    const expected = data.subject ? data.subject.toLowerCase() : null;
    if (expected && data.subject_lowercase !== expected) {
      quizBatch.update(doc.ref, { subject_lowercase: expected });
      quizCount++;
    }
  }
  if (quizCount > 0) {
    await quizBatch.commit();
    console.log(`Quizzes: Updated ${quizCount} documents.\n`);
  } else {
    console.log('Quizzes: No updates needed.\n');
  }

  console.log('=== Migration Complete ===');
  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
