#!/usr/bin/env node
// Verify every wilaya and commune the backend actually serves has a Latin name
// in lib/core/place_names.dart.
//
// placeName() falls back to the Arabic string for anything unlisted, so a
// commune added in the dashboard's قوائم التسجيل and not here shows up as
// Arabic in the French and English UI -- silently, with no error anywhere.
// That is exactly how ~54 communes ended up untranslated.
//
// Usage: node tool/check-place-names.js [apiBase]
//   apiBase defaults to the production server.

const fs = require('fs');
const path = require('path');

const API = process.argv[2] || 'https://wiinz-server.onrender.com/api';
const dartPath = path.join(__dirname, '..', 'lib', 'core', 'place_names.dart');

function latinKeys(src) {
  // Grab the _latin map body, then every 'key': 'value' pair in it.
  const start = src.indexOf('const _latin');
  const open = src.indexOf('{', start);
  let depth = 0, i = open, end = -1;
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
  }
  const body = src.slice(open, end);
  const keys = new Map();
  const re = /'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'/g;
  let m;
  while ((m = re.exec(body)) !== null) keys.set(m[1], m[2]);
  return keys;
}

(async () => {
  const src = fs.readFileSync(dartPath, 'utf8');
  const latin = latinKeys(src);

  let data;
  try {
    const r = await fetch(`${API}/locations`);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    data = await r.json();
  } catch (e) {
    console.error(`Could not reach ${API}/locations : ${e.message}`);
    console.error('(the backend is on a free instance -- retry if it was asleep)');
    process.exit(2);
  }

  const wilayas = data.wilayas || [];
  const cbw = data.communesByWilaya || {};

  const missing = [];
  for (const w of wilayas) if (!latin.has(w)) missing.push({ kind: 'wilaya', name: w });
  let communeCount = 0;
  for (const [w, list] of Object.entries(cbw)) {
    for (const c of list) {
      communeCount++;
      if (!latin.has(c)) missing.push({ kind: 'commune', name: c, wilaya: w });
    }
  }

  console.log(`place_names.dart entries : ${latin.size}`);
  console.log(`wilayas served           : ${wilayas.length}`);
  console.log(`communes served          : ${communeCount}`);
  console.log(`missing Latin names      : ${missing.length}`);

  if (missing.length) {
    console.log('\nMissing -- these render as Arabic in FR/EN:');
    for (const m of missing) {
      console.log(`  ${m.kind.padEnd(8)} ${JSON.stringify(m.name)}${m.wilaya ? '  (' + m.wilaya + ')' : ''}`);
    }
    process.exit(1);
  }

  // Spot-check a few so a silently-empty map can't pass.
  const samples = [...wilayas.slice(0, 2), ...(cbw[wilayas[0]] || []).slice(0, 3)];
  console.log('\nSample resolutions:');
  for (const s of samples) console.log(`  ${s}  ->  ${latin.get(s)}`);
  console.log('\nOK: every served place has a Latin name.');
})();
