const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Migration map: old value -> new value
const TYPE_MAP = {
  'Book':       'textbook',
  'Notes':      'notes',
  'Past Paper': 'past_paper',
};

const CLASS_LEVEL_MAP = {
  '9th Grade': '9',
};

async function run() {
  console.log('=== Firestore Type Migration ===\n');

  const snapshot = await db.collection('resources').get();

  if (snapshot.empty) {
    console.log('No documents found in resources collection. Exiting.');
    process.exit(0);
  }

  console.log(`Found ${snapshot.size} documents. Scanning for stale type values...\n`);

  // Firestore allows max 500 writes per batch
  const BATCH_SIZE = 499;
  let batches = [];
  let currentBatch = db.batch();
  let currentBatchCount = 0;
  let patchCount = 0;
  let skipCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};

    const newType = TYPE_MAP[data.type];
    if (newType) updates.type = newType;

    const newClassLevel = CLASS_LEVEL_MAP[data.classLevel];
    if (newClassLevel) updates.classLevel = newClassLevel;

    if (Object.keys(updates).length > 0) {
      currentBatch.update(doc.ref, updates);
      patchCount++;
      currentBatchCount++;
      console.log(`  [PATCH] ${doc.id}:`, JSON.stringify(updates));

      if (currentBatchCount >= BATCH_SIZE) {
        batches.push(currentBatch);
        currentBatch = db.batch();
        currentBatchCount = 0;
      }
    } else {
      skipCount++;
    }
  }

  // Push the last (possibly partial) batch
  if (currentBatchCount > 0) {
    batches.push(currentBatch);
  }

  if (patchCount === 0) {
    console.log('\nAll documents already have correct type values. Nothing to update.');
    process.exit(0);
  }

  // Commit all batches
  console.log(`\nCommitting ${batches.length} batch(es) with ${patchCount} update(s)...`);
  await Promise.all(batches.map(b => b.commit()));

  console.log('\n=== Migration Complete ===');
  console.log(`Patched : ${patchCount} documents`);
  console.log(`Skipped : ${skipCount} documents (already correct)`);

  process.exit(0);
}

run().catch(err => {
  console.error('Fatal error during migration:', err);
  process.exit(1);
});
