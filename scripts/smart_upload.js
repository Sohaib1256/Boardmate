const fs = require('fs');
const path = require('path');
const cloudinary = require('cloudinary').v2;
const admin = require('firebase-admin');

// ==========================================
// 1. Configuration
// ==========================================

// Cloudinary Config
cloudinary.config({ 
  cloud_name: 'djblpxrmp', 
  api_key: '672671275435859', 
  api_secret: 'd6_hXfIRIrzT2fdKl-gc8xH7vAQ' 
});

// Firebase Config
const serviceAccount = require('./serviceAccountKey.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}
const db = admin.firestore();

// Application Data Config
const DEFAULT_CLASS_LEVEL = '9';
const ADMIN_UID = '64RGxC4QSSfKz5F2l3qcgsvYhTX2';

// Source folders
const UPLOAD_DIRECTORY = 'D:\\Downloads\\compressed_pdfs';

// Supported file extensions
const SUPPORTED_EXTENSIONS = ['.pdf', '.docx', '.doc'];

// ==========================================
// 2. Helpers
// ==========================================

function getAllFiles(dir) {
  let results = [];
  if (!fs.existsSync(dir)) {
    console.warn(`  WARNING: Source folder not found: ${dir}`);
    return results;
  }
  for (const file of fs.readdirSync(dir)) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      results = results.concat(getAllFiles(fullPath));
    } else if (SUPPORTED_EXTENSIONS.includes(path.extname(file).toLowerCase())) {
      results.push(fullPath);
    }
  }
  return results;
}

function parseFileInfo(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const fileName = path.basename(filePath, ext);
  const dirName = path.basename(path.dirname(filePath));
  const lowerName = fileName.toLowerCase();
  const lowerDir = dirName.toLowerCase();

  // 1. Determine Resource Type
  let resourceType = 'notes'; // Default
  if (lowerName.includes('book') || lowerDir.includes('book')) resourceType = 'textbook';
  if (lowerName.includes('notes') || lowerDir.includes('notes')) resourceType = 'notes';
  if (lowerDir.includes('pastpaper') || lowerDir.includes('past paper') || 
      lowerName.includes('past') || lowerName.includes('paper') ||
      ext === '.docx' || ext === '.doc') resourceType = 'past_paper';

  // 2. Determine Subject
  let subject = 'General';
  if (lowerName.includes('math')) subject = 'Mathematics';
  else if (lowerName.includes('physics')) subject = 'Physics';
  else if (lowerName.includes('chemistry')) subject = 'Chemistry';
  else if (lowerName.includes('biology')) subject = 'Biology';
  else if (lowerName.includes('english')) subject = 'English';
  else if (lowerName.includes('urdu')) subject = 'Urdu';
  else if (lowerName.includes('islamiat')) subject = 'Islamiat';
  else if (lowerName.includes('computer')) subject = 'Computer Science';
  else if (lowerName.includes('pak') || lowerName.includes('pakistan')) subject = 'Pak Studies';

  // 3. Determine Chapter / Year
  let chapter = 'All';
  const yearMatch = lowerName.match(/\b(20\d{2})\b/);
  const chapterMatch = lowerName.match(/(?:chapter|unit|ch)[\s_-]*(\d+)/i);
  if (yearMatch) {
    chapter = `Year ${yearMatch[1]}`;
  } else if (chapterMatch) {
    chapter = `Chapter ${chapterMatch[1]}`;
  }

  // 4. Clean up Title
  let title = fileName.replace(/[-_]/g, ' ').trim();

  return { subject, resourceType, chapter, title };
}

// ==========================================
// 3. Main Execution
// ==========================================

async function run() {
  console.log('=== Smart Bulk Upload Script ===\n');

  const allFiles = getAllFiles(UPLOAD_DIRECTORY);
  
  if (allFiles.length === 0) {
    console.log(`No supported files found in ${UPLOAD_DIRECTORY}. Exiting.`);
    process.exit(0);
  }

  console.log(`Total files found: ${allFiles.length}\n`);
  console.log('--- Starting Smart Upload ---\n');

  let successCount = 0;
  let failCount = 0;
  let skipCount = 0;

  for (const filePath of allFiles) {
    const fileName = path.basename(filePath);
    const { subject, resourceType, chapter, title } = parseFileInfo(filePath);

    console.log(`Processing: ${fileName}`);
    
    try {
      // 1. Deduplication Check
      const existingQuery = await db.collection('resources')
        .where('title', '==', title)
        .limit(1)
        .get();

      if (!existingQuery.empty) {
        console.log(`  -> Duplicate Skipped (Title already exists: "${title}")\n`);
        skipCount++;
        continue;
      }

      console.log(`  Subject: ${subject} | Type: ${resourceType} | Chapter: ${chapter}`);

      // 2. Upload to Cloudinary
      const cloudinaryResult = await new Promise((resolve, reject) => {
        cloudinary.uploader.upload_large(filePath, {
          resource_type: 'raw',
          folder: 'boardmate_resources',
          public_id: `${resourceType.replace(/\s/g,'_')}/${fileName.replace(/[^a-zA-Z0-9.]/g, '_')}`
        }, (error, result) => {
          if (error) reject(error);
          else resolve(result);
        });
      });

      console.log(`  -> Cloudinary: ${cloudinaryResult.secure_url}`);

      // 3. Strict URL & Search Normalization before Firestore save
      const secureUrl = cloudinaryResult.secure_url;
      const titleLowercase = title.toLowerCase();
      const subjectLowercase = subject.toLowerCase();

      const resourceData = {
        title: title,
        title_lowercase: titleLowercase,
        type: resourceType,
        classLevel: DEFAULT_CLASS_LEVEL,
        subject: subject,
        subject_lowercase: subjectLowercase,
        chapter: chapter,
        fileUrl: secureUrl, // Must use strict secure_url
        uploadedBy: ADMIN_UID,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Save to Firestore
      const docRef = await db.collection('resources').add(resourceData);
      console.log(`  -> Firestore: resources/${docRef.id}\n`);

      successCount++;
    } catch (error) {
      console.error(`  -> ERROR: ${error.message || JSON.stringify(error)}\n`);
      failCount++;
    }
  }

  console.log('=== Upload Complete ===');
  console.log(`Success : ${successCount} files`);
  console.log(`Skipped : ${skipCount} files`);
  console.log(`Failed  : ${failCount} files`);

  process.exit(0);
}

run();
