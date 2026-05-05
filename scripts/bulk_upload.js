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
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Application Data Config
const DEFAULT_CLASS_LEVEL = '9';
const ADMIN_UID = '64RGxC4QSSfKz5F2l3qcgsvYhTX2';

// Source folders — add or remove as needed
const SOURCE_FOLDERS = [
  'D:\\Downloads\\compressed_pdfs',                                           // Books & Notes (compressed PDFs)
  'D:\\Downloads\\wetransfer_fyp-data_2026-04-14_1756\\9_class_pastpapers',  // Past Papers (.docx)
];

// Supported file extensions
const SUPPORTED_EXTENSIONS = ['.pdf', '.docx', '.doc'];

// ==========================================
// 2. Helpers
// ==========================================

function getAllFiles(dir) {
  let results = [];
  if (!fs.existsSync(dir)) {
    console.warn(`  WARNING: Source folder not found, skipping: ${dir}`);
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

  // 1. Determine Resource Type (must match app's exact Firestore values)
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

  // 3. Determine Chapter / Year (for past papers, extract the year)
  let chapter = 'All';
  const yearMatch = lowerName.match(/\b(20\d{2})\b/);
  const chapterMatch = lowerName.match(/(?:chapter|unit|ch)[\s_-]*(\d+)/i);
  if (yearMatch) {
    chapter = `Year ${yearMatch[1]}`;
  } else if (chapterMatch) {
    chapter = `Chapter ${chapterMatch[1]}`;
  }

  // 4. Clean up Title — make it human-readable
  let title = fileName.replace(/[-_]/g, ' ').trim();

  return { subject, resourceType, chapter, title };
}

// ==========================================
// 3. Main Execution
// ==========================================

async function run() {
  console.log('=== BoardMate Bulk Upload Script ===\n');

  // Collect all files from all source folders
  let allFiles = [];
  for (const folder of SOURCE_FOLDERS) {
    const found = getAllFiles(folder);
    console.log(`  ${folder}`);
    console.log(`  -> Found ${found.length} file(s)\n`);
    allFiles = allFiles.concat(found);
  }

  if (allFiles.length === 0) {
    console.log('No supported files found. Exiting.');
    process.exit(0);
  }

  console.log(`Total files to upload: ${allFiles.length}\n`);
  console.log('--- Starting Upload ---\n');

  let successCount = 0;
  let failCount = 0;

  for (const filePath of allFiles) {
    const fileName = path.basename(filePath);
    const { subject, resourceType, chapter, title } = parseFileInfo(filePath);

    console.log(`Processing: ${fileName}`);
    console.log(`  Subject: ${subject} | Type: ${resourceType} | Chapter: ${chapter}`);

    try {
      // Step 1: Upload to Cloudinary
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

      // Step 2: Save to Firestore
      const resourceData = {
        title: title,
        type: resourceType,
        classLevel: DEFAULT_CLASS_LEVEL,
        subject: subject,
        chapter: chapter,
        fileUrl: cloudinaryResult.secure_url,
        uploadedBy: ADMIN_UID,
        uploadedAt: admin.firestore.FieldValue.serverTimestamp()
      };

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
  console.log(`Failed  : ${failCount} files`);

  process.exit(0);
}

run();
