/**
 * Links the app's own 44 adhkar to the Hisn al-Muslim recitations by matching
 * their text, so the older section gains audio without inventing a source.
 *
 * Matching is done on the consonantal skeleton — diacritics, hamza forms and
 * punctuation differ between the two datasets even where the words are
 * identical. Only high-confidence matches are emitted; a wrong link would play
 * the wrong supplication, which is worse than no button.
 */
const fs = require('fs');

const DART = process.argv[2];
const HISN = process.argv[3];
if (!DART || !HISN) throw new Error('usage: node match_audio.js <adhkar_data.dart> <hisn.json>');

const STRIP = new RegExp(
  '[' +
    '\\u0610-\\u061A\\u064B-\\u065F\\u0670\\u06D6-\\u06ED' +
    '\\u08D3-\\u08FF\\u0640\\u200B-\\u200F\\uFEFF' +
    ']',
  'g'
);

const skeleton = (s) =>
  s
    .replace(STRIP, '')
    .replace(/ٱ/g, 'ا')
    .replace(/[آأإ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ء/g, '')
    .replace(/[^؀-ۿ]/g, '');

// ---- read the app's adhkar out of the Dart source -----------------------
const dart = fs.readFileSync(DART, 'utf8');
const adhkar = [];
const re = /Dhikr\(id:\s*'([^']+)',[\s\S]*?text:\s*'([^']*)'/g;
let m;
while ((m = re.exec(dart)) !== null) {
  adhkar.push({ id: m[1], text: m[2] });
}

const hisn = JSON.parse(fs.readFileSync(HISN, 'utf8'))
  .chapters.flatMap((c) => c.items.map((i) => ({ ...i, chapter: c.title })))
  .filter((i) => i.au != null);

console.log(`app adhkar: ${adhkar.length}, hisn recitations: ${hisn.length}\n`);

// ---- match ---------------------------------------------------------------
const results = [];
for (const d of adhkar) {
  const a = skeleton(d.text);
  let best = null;

  for (const h of hisn) {
    const b = skeleton(h.t);
    if (!a || !b) continue;

    // Exact skeleton equality only.
    //
    // Substring and prefix similarity were tried and produced dangerous links:
    // a short dhikr matched any longer one that happened to contain it (the
    // tahlil matched the whole morning supplication), Al-Falaq matched
    // Al-Ikhlas, and the evening "بك أمسينا" matched its morning counterpart —
    // a different supplication entirely. Playing the wrong dua is worse than
    // offering no audio, so only identical text counts.
    const score = a === b ? 1 : 0;
    if (score === 1 && !best) best = { score, h };
  }

  results.push({ ...d, best });
}

const CONFIDENT = 1;
const matched = results.filter((r) => r.best && r.best.score >= CONFIDENT);
const unmatched = results.filter((r) => !r.best || r.best.score < CONFIDENT);

console.log(`✓ confident matches: ${matched.length}`);
console.log(`✗ no confident match: ${unmatched.length}\n`);

console.log('--- MATCHES (review these) ---');
for (const r of matched) {
  console.log(
    `${r.id.padEnd(12)} au=${String(r.best.h.au).padEnd(4)} score=${r.best.score.toFixed(2)}`
  );
  console.log(`   ours : ${r.text.slice(0, 70)}`);
  console.log(`   hisn : ${r.best.h.t.slice(0, 70)}`);
}

console.log('\n--- UNMATCHED ---');
for (const r of unmatched) {
  console.log(`${r.id.padEnd(12)} best=${r.best ? r.best.score.toFixed(2) : 'none'}  ${r.text.slice(0, 60)}`);
}

// Emit the mapping for the app to bundle.
fs.writeFileSync(
  'audio_map.json',
  JSON.stringify(Object.fromEntries(matched.map((r) => [r.id, r.best.h.au])), null, 2)
);
console.log(`\nwrote audio_map.json with ${matched.length} entries`);
