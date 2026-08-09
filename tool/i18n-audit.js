#!/usr/bin/env node
// WIIN i18n audit.
//
// The dictionaries in lib/core/i18n.dart are keyed by the ARABIC SOURCE STRING.
// So `tr('نص')` silently falls back to Arabic if that exact literal is missing
// from _fr / _en -- there is no compile-time check. This script is that check.
//
// Reports, per app:
//   - keys used by tr()/trf()/trNav() that are missing from _fr and/or _en
//   - keys containing $interpolation (can never match a dictionary entry)
//   - dictionary entries nothing references any more (dead weight)
//
// Usage: node i18n-audit.js <path-to-flutter-app> [...more apps]

const fs = require('fs');
const path = require('path');

// ---- helpers ---------------------------------------------------------------

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.dart')) out.push(p);
  }
  return out;
}

// Strip // line comments and /* */ block comments, without touching the
// contents of string literals (a URL's "//" must survive).
function stripComments(src) {
  let out = '';
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === "'" || c === '"') {
      const q = c;
      out += c; i++;
      while (i < n) {
        if (src[i] === '\\') { out += src[i] + (src[i + 1] || ''); i += 2; continue; }
        out += src[i];
        if (src[i] === q) { i++; break; }
        i++;
      }
      continue;
    }
    if (c === '/' && src[i + 1] === '/') { while (i < n && src[i] !== '\n') i++; continue; }
    if (c === '/' && src[i + 1] === '*') {
      i += 2;
      while (i < n && !(src[i] === '*' && src[i + 1] === '/')) i++;
      i += 2;
      continue;
    }
    out += c; i++;
  }
  return out;
}

// Read a Dart single-quoted literal starting at src[i] === "'".
// Returns {value, end} or null. Handles \' escapes.
function readLiteral(src, i) {
  const q = src[i];
  if (q !== "'" && q !== '"') return null;
  let v = '';
  i++;
  while (i < src.length) {
    const c = src[i];
    if (c === '\\') { v += c + (src[i + 1] || ''); i += 2; continue; }
    if (c === q) return { value: v, end: i + 1 };
    if (c === '\n') return null; // not a simple one-line literal
    v += c; i++;
  }
  return null;
}

// Extract the keys of a `... _name = { ... };` map literal.
function extractMapKeys(src, name) {
  const m = new RegExp(`_${name}\\s*=\\s*\\{`).exec(src);
  if (!m) return null;
  let i = m.index + m[0].length;
  let depth = 1;
  const keys = new Set();
  let expectKey = true;
  while (i < src.length && depth > 0) {
    const c = src[i];
    if (c === '{') { depth++; i++; expectKey = false; continue; }
    if (c === '}') { depth--; i++; continue; }
    if (c === ',') { if (depth === 1) expectKey = true; i++; continue; }
    if ((c === "'" || c === '"') && depth === 1 && expectKey) {
      const lit = readLiteral(src, i);
      if (lit) {
        // Only count it as a key if a ':' follows.
        let j = lit.end;
        while (j < src.length && /\s/.test(src[j])) j++;
        if (src[j] === ':') { keys.add(lit.value); expectKey = false; }
        i = lit.end;
        continue;
      }
    }
    if (c === "'" || c === '"') { const lit = readLiteral(src, i); if (lit) { i = lit.end; continue; } }
    i++;
  }
  return keys;
}

// Find every tr('..') / trf('..') / trNav('..') literal argument.
function extractUsedKeys(src) {
  const used = [];
  const re = /\b(tr|trf|trNav)\s*\(\s*/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const lit = readLiteral(src, re.lastIndex);
    if (lit) used.push({ fn: m[1], key: lit.value });
  }
  return used;
}

// ---- per-app audit ---------------------------------------------------------

function audit(appDir) {
  const libDir = path.join(appDir, 'lib');
  const i18nPath = path.join(libDir, 'core', 'i18n.dart');
  const label = path.basename(appDir);

  if (!fs.existsSync(i18nPath)) {
    console.log(`\n### ${label}\n  no lib/core/i18n.dart -- skipped`);
    return { label, skipped: true };
  }

  const i18nSrc = stripComments(fs.readFileSync(i18nPath, 'utf8'));
  const fr = extractMapKeys(i18nSrc, 'fr');
  const en = extractMapKeys(i18nSrc, 'en');

  const files = walk(libDir);
  const usedByKey = new Map(); // key -> Set(relative file)
  for (const f of files) {
    const src = stripComments(fs.readFileSync(f, 'utf8'));
    for (const { key } of extractUsedKeys(src)) {
      if (!usedByKey.has(key)) usedByKey.set(key, new Set());
      usedByKey.get(key).add(path.relative(appDir, f));
    }
  }

  const interpolated = [];
  const missingFr = [];
  const missingEn = [];

  for (const [key, where] of usedByKey) {
    // A key built with string interpolation can never match a dictionary entry.
    if (/\$\{?\w/.test(key)) { interpolated.push({ key, where: [...where] }); continue; }
    // Pure-ASCII keys are typically brand names/format tokens, not translatable
    // Arabic source strings; flag only keys that contain Arabic script.
    const hasArabic = /[؀-ۿ]/.test(key);
    if (!hasArabic) continue;
    if (!fr.has(key)) missingFr.push({ key, where: [...where] });
    if (!en.has(key)) missingEn.push({ key, where: [...where] });
  }

  const unusedFr = [...fr].filter(k => !usedByKey.has(k));
  const unusedEn = [...en].filter(k => !usedByKey.has(k));

  console.log(`\n### ${label}`);
  console.log(`  dart files scanned      : ${files.length}`);
  console.log(`  distinct tr() keys used : ${usedByKey.size}`);
  console.log(`  _fr entries             : ${fr.size}`);
  console.log(`  _en entries             : ${en.size}`);
  console.log(`  MISSING from _fr        : ${missingFr.length}`);
  console.log(`  MISSING from _en        : ${missingEn.length}`);
  console.log(`  interpolated keys       : ${interpolated.length}`);
  console.log(`  unused _fr entries      : ${unusedFr.length}`);
  console.log(`  unused _en entries      : ${unusedEn.length}`);

  const show = (title, arr) => {
    if (!arr.length) return;
    console.log(`\n  -- ${title} --`);
    for (const { key, where } of arr.slice(0, 40)) {
      console.log(`    ${JSON.stringify(key)}`);
      console.log(`        ${where.join(', ')}`);
    }
    if (arr.length > 40) console.log(`    ... and ${arr.length - 40} more`);
  };
  show('missing from _fr', missingFr);
  show('missing from _en', missingEn);
  show('interpolated (cannot ever translate)', interpolated);

  return {
    label,
    used: usedByKey.size,
    fr: fr.size, en: en.size,
    missingFr: missingFr.length, missingEn: missingEn.length,
    interpolated: interpolated.length,
    unusedFr: unusedFr.length, unusedEn: unusedEn.length,
  };
}

// ---- main ------------------------------------------------------------------

const apps = process.argv.slice(2);
if (!apps.length) {
  console.error('usage: node i18n-audit.js <flutter-app-dir> [...]');
  process.exit(2);
}

console.log('WIIN i18n audit');
console.log('===============');
const results = apps.map(audit).filter(r => !r.skipped);

console.log('\n\nSUMMARY');
console.log('-------');
let bad = 0;
for (const r of results) {
  const problems = r.missingFr + r.missingEn + r.interpolated;
  if (problems) bad += problems;
  console.log(
    `  ${r.label.padEnd(14)} used=${String(r.used).padStart(4)}  ` +
    `fr=${String(r.fr).padStart(4)} en=${String(r.en).padStart(4)}  ` +
    `missing_fr=${r.missingFr} missing_en=${r.missingEn} interpolated=${r.interpolated}  ` +
    `unused_fr=${r.unusedFr} unused_en=${r.unusedEn}`
  );
}
console.log(bad === 0
  ? '\nRESULT: clean -- 0 missing, 0 interpolated.'
  : `\nRESULT: ${bad} problem(s) -- see above.`);
process.exit(bad === 0 ? 0 : 1);
