const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

// Set to true to actually delete files, false to just preview
const DRY_RUN = false; 

async function purgeResources() {
  console.log(`=== Resource Purge Script [DRY RUN: ${DRY_RUN}] ===\n`);
  
  try {
    const snapshot = await db.collection('resources').get();
    
    let keepCount = 0;
    let deleteCount = 0;
    let docsToDelete = [];

    snapshot.forEach((doc) => {
      const data = doc.data();
      const type = (data.type || '').toLowerCase().replace(/[-_ ]/g, '');
      
      // Check variations of "pastpaper"
      if (type === 'pastpaper' || type === 'pastpapers') {
        keepCount++;
        // console.log(`KEEP: ${data.title} (Type: ${data.type})`);
      } else {
        deleteCount++;
        docsToDelete.push({ id: doc.id, title: data.title, type: data.type });
        // console.log(`DELETE: ${data.title} (Type: ${data.type})`);
      }
    });

    console.log(`\n--- Summary ---`);
    console.log(`Total Resources: ${snapshot.size}`);
    console.log(`To Keep (Past Papers): ${keepCount}`);
    console.log(`To Delete (Others): ${deleteCount}`);

    if (DRY_RUN) {
      console.log('\nDry run complete. Set DRY_RUN = false to execute deletions.');
    } else {
      console.log('\nExecuting deletions...');
      
      // Batch deletes (max 500 per batch)
      let batch = db.batch();
      let count = 0;
      let totalDeleted = 0;

      for (const item of docsToDelete) {
        const docRef = db.collection('resources').doc(item.id);
        batch.delete(docRef);
        count++;

        if (count === 500) {
          await batch.commit();
          totalDeleted += count;
          console.log(`Committed batch of 500. Total deleted so far: ${totalDeleted}`);
          batch = db.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
        totalDeleted += count;
      }

      console.log(`\nDeletion complete. Total documents deleted: ${totalDeleted}`);
    }
  } catch (error) {
    console.error('Error during purge:', error);
  }
}

purgeResources();
