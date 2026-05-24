/**
 * BUILD SCRIPT — KURBAN DIGITAL
 * ============================================================
 * 1. Obfuscasi src/app.js  → public/app.js (tersamar)
 * 2. Copy semua static files → public/
 *
 * Vercel akan serve folder public/ langsung via CDN.
 * Jalankan: node build.js
 * ============================================================
 */

const JavaScriptObfuscator = require('javascript-obfuscator');
const fs   = require('fs');
const path = require('path');

const ROOT       = __dirname;
const SRC_FILE   = path.join(ROOT, 'src', 'app.js');
const PUBLIC_DIR = path.join(ROOT, 'public');

console.log('🔧 Kurban Digital — Build & Obfuscation Script');
console.log('='.repeat(52));

// ── Buat folder public/ ──────────────────────────────────
fs.mkdirSync(PUBLIC_DIR, { recursive: true });

// ── Baca source file ─────────────────────────────────────
if (!fs.existsSync(SRC_FILE)) {
    console.error('❌ ERROR: src/app.js tidak ditemukan!');
    process.exit(1);
}

const sourceCode = fs.readFileSync(SRC_FILE, 'utf8');
console.log(`📂 Source   : src/app.js (${(sourceCode.length / 1024).toFixed(1)} KB)`);

// ── Obfuscate ────────────────────────────────────────────
console.log('🔒 Menjalankan obfuscasi...');

const obfuscationResult = JavaScriptObfuscator.obfuscate(sourceCode, {
    compact: true,
    controlFlowFlattening: false,
    deadCodeInjection: false,
    debugProtection: false,
    debugProtectionInterval: 0,
    disableConsoleOutput: false,
    identifierNamesGenerator: 'hexadecimal',
    log: false,
    numbersToExpressions: false,
    renameGlobals: false,
    selfDefending: false,
    simplify: true,
    splitStrings: true,
    splitStringsChunkLength: 10,
    stringArray: true,
    stringArrayCallsTransform: true,
    stringArrayCallsTransformThreshold: 0.5,
    stringArrayEncoding: ['base64'],
    stringArrayIndexShift: true,
    stringArrayRotate: true,
    stringArrayShuffle: true,
    stringArrayWrappersCount: 2,
    stringArrayWrappersChunkLength: 10,
    stringArrayWrappersParametersMaxCount: 4,
    stringArrayWrappersType: 'function',
    stringArrayThreshold: 0.75,
    unicodeEscapeSequence: false,
    seed: 0
});

const obfuscatedCode = obfuscationResult.getObfuscatedCode();
const outAppJs = path.join(PUBLIC_DIR, 'app.js');
fs.writeFileSync(outAppJs, obfuscatedCode, 'utf8');
console.log(`✅ app.js   : public/app.js (${(obfuscatedCode.length / 1024).toFixed(1)} KB, obfuscated)`);

// ── Copy static files ke public/ ────────────────────────
console.log('📋 Menyalin static files ke public/ ...');

// File tunggal di root
const staticFiles = [
    'index.html',
    'style.css',
    'qris.png',
    'qr.png',
    'bg-mosque.png',
    'sharing_eid_adha.png',
];

staticFiles.forEach(file => {
    const src = path.join(ROOT, file);
    if (fs.existsSync(src)) {
        fs.copyFileSync(src, path.join(PUBLIC_DIR, file));
        console.log(`   ✓ ${file}`);
    }
});

// Folder lagu/ (rekursif)
function copyDirRecursive(srcDir, destDir) {
    if (!fs.existsSync(srcDir)) return;
    fs.mkdirSync(destDir, { recursive: true });
    fs.readdirSync(srcDir).forEach(item => {
        const srcItem  = path.join(srcDir, item);
        const destItem = path.join(destDir, item);
        if (fs.statSync(srcItem).isDirectory()) {
            copyDirRecursive(srcItem, destItem);
        } else {
            fs.copyFileSync(srcItem, destItem);
        }
    });
}

const laguSrc  = path.join(ROOT, 'lagu');
const laguDest = path.join(PUBLIC_DIR, 'lagu');
if (fs.existsSync(laguSrc)) {
    copyDirRecursive(laguSrc, laguDest);
    console.log(`   ✓ lagu/ (${fs.readdirSync(laguSrc).length} file)`);
}

console.log('');
console.log('✨ Build selesai! Folder public/ siap untuk deploy ke Vercel.');
console.log('='.repeat(52));
