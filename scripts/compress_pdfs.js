const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const util = require('util');

const execPromise = util.promisify(exec);

// ==========================================
// Configuration
// ==========================================
const INPUT_FOLDER  = 'D:\\Downloads\\wetransfer_fyp-data_2026-04-14_1756';
const OUTPUT_FOLDER = 'D:\\Downloads\\compressed_pdfs'; // Compressed files go here

// Quality Preset — change if needed:
//   /screen   = lowest quality, smallest file (~72 DPI) — for viewing on screen only
//   /ebook    = good quality, much smaller file (~150 DPI) — RECOMMENDED for textbooks
//   /printer  = high quality, moderate compression (~300 DPI)
//   /prepress = highest quality, least compression
const QUALITY = '/ebook';

// ==========================================
// Helpers
// ==========================================
function getAllPdfs(dir) {
  let results = [];
  if (!fs.existsSync(dir)) return results;
  for (const file of fs.readdirSync(dir)) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      results = results.concat(getAllPdfs(fullPath));
    } else if (file.toLowerCase().endsWith('.pdf')) {
      results.push(fullPath);
    }
  }
  return results;
}

function formatMB(bytes) {
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

function ensureDirExists(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
    console.log(`Created output folder: ${dirPath}\n`);
  }
}

// Ghostscript executable — full path to avoid PATH issues
async function detectGhostscript() {
  const knownPath = 'C:\\Program Files\\gs\\gs10.07.0\\bin\\gswin64c.exe';
  if (fs.existsSync(knownPath)) {
    return `"${knownPath}"`;
  }
  // Fallback: try common command names in PATH
  for (const cmd of ['gswin64c', 'gswin32c', 'gs']) {
    try {
      await execPromise(`${cmd} --version`);
      return cmd;
    } catch {
      // not found, try next
    }
  }
  return null;
}

// ==========================================
// Main Execution
// ==========================================
async function run() {
  console.log('--- PDF Compression Script ---\n');

  // Check Ghostscript is available
  const gsCmd = await detectGhostscript();
  if (!gsCmd) {
    console.error('ERROR: Ghostscript is not installed or not found in PATH.');
    console.error('Please install it from https://www.ghostscript.com/releases/gsdnld.html');
    console.error('Download the 64-bit Windows installer, install it, then re-run this script.');
    process.exit(1);
  }
  console.log(`Ghostscript found: ${gsCmd}\n`);

  ensureDirExists(OUTPUT_FOLDER);

  const pdfs = getAllPdfs(INPUT_FOLDER);
  if (pdfs.length === 0) {
    console.log('No PDFs found in input folder.');
    process.exit(0);
  }

  console.log(`Found ${pdfs.length} PDF(s). Compressing with quality preset: ${QUALITY}\n`);

  let successCount = 0;
  let failCount = 0;
  let totalOriginalBytes = 0;
  let totalCompressedBytes = 0;

  for (const inputPath of pdfs) {
    const fileName = path.basename(inputPath);
    const outputPath = path.join(OUTPUT_FOLDER, fileName);
    const originalSize = fs.statSync(inputPath).size;

    process.stdout.write(`  Compressing: ${fileName} (${formatMB(originalSize)}) ... `);

    const gsCommand = [
      gsCmd,
      '-sDEVICE=pdfwrite',
      '-dCompatibilityLevel=1.4',
      `-dPDFSETTINGS=${QUALITY}`,
      '-dNOPAUSE',
      '-dQUIET',
      '-dBATCH',
      `-sOutputFile="${outputPath}"`,
      `"${inputPath}"`
    ].join(' ');

    try {
      await execPromise(gsCommand);

      const compressedSize = fs.statSync(outputPath).size;
      const savings = (((originalSize - compressedSize) / originalSize) * 100).toFixed(1);

      totalOriginalBytes += originalSize;
      totalCompressedBytes += compressedSize;

      console.log(`Done! ${formatMB(compressedSize)} (saved ${savings}%)`);
      successCount++;
    } catch (err) {
      console.log('FAILED');
      console.error(`    -> Error: ${err.message}`);
      failCount++;
    }
  }

  // Summary
  const totalSavings = (((totalOriginalBytes - totalCompressedBytes) / totalOriginalBytes) * 100).toFixed(1);
  console.log('\n--- Compression Complete ---');
  console.log(`Success : ${successCount} files`);
  console.log(`Failed  : ${failCount} files`);
  console.log(`Before  : ${formatMB(totalOriginalBytes)}`);
  console.log(`After   : ${formatMB(totalCompressedBytes)}`);
  console.log(`Saved   : ${totalSavings}% reduction`);
  console.log(`\nOutput folder: ${OUTPUT_FOLDER}`);
}

run();
