/**
 * Builds the app's Quran assets.
 *
 * Text:     KFGQPC Uthmanic Hafs (مجمع الملك فهد) — the Saudi standard, the
 *           same rasm/diacritic encoding quran.ksu.edu.sa displays.
 * Metadata: surah names, revelation type, sajda positions — taken from the
 *           alquran.cloud dump (structure only, not scripture text), which
 *           also serves as an independent reference for the integrity check.
 *
 * All Arabic in this file is written as \u escapes on purpose: these marks are
 * invisible or visually identical in source, and the two editions encode them
 * differently, so literal text here would be unreviewable and edit-hostile.
 */
const fs = require('fs');
const path = require('path');

const OUT = process.argv[2];
if (!OUT) throw new Error('usage: node build_quran_assets.js <outDir>');

const MECCAN = 'مكية'; // مكية
const MEDINAN = 'مدنية'; // مدنية

const text = JSON.parse(fs.readFileSync('kfgqpc.json', 'utf8')).quran;
const meta = JSON.parse(fs.readFileSync('quran_raw.json', 'utf8')).data;

const clean = (s) => s.replace(/﻿/g, '').trim();

// Group the flat KFGQPC verse list by surah.
const bySurah = new Map();
for (const v of text) {
  if (!bySurah.has(v.chapter)) bySurah.set(v.chapter, []);
  bySurah.get(v.chapter).push(v);
}

const BASMALA = clean(bySurah.get(1)[0].text);

/// A few surahs in this edition carry a leftover piece of the Basmala welded
/// to the front of ayah 1 (Al-Qadr ships with its final word attached).
/// Strips any leading fragment that is a trailing run of Basmala words.
function stripBasmalaFragment(t) {
  const words = BASMALA.split(' ');
  for (let start = 0; start < words.length; start++) {
    const tail = words.slice(start).join(' ');
    if (t.startsWith(tail)) return { text: t.slice(tail.length).trim(), tail };
  }
  return null;
}

const index = [];
const repairs = [];
let totalAyahs = 0;
let totalSajdas = 0;

for (const m of meta.surahs) {
  const verses = bySurah.get(m.number);
  if (!verses) throw new Error(`missing surah ${m.number} in text source`);
  if (verses.length !== m.ayahs.length) {
    throw new Error(
      `surah ${m.number}: text has ${verses.length} ayahs, metadata says ${m.ayahs.length}`
    );
  }

  const sajdaAt = new Set(
    m.ayahs.filter((a) => a.sajda).map((a) => a.numberInSurah)
  );

  const ayahs = verses.map((v, i) => {
    let t = clean(v.text);
    if (!t) throw new Error(`empty ayah at ${m.number}:${v.verse}`);

    // This edition keeps the Basmala out of every opening ayah except
    // Al-Fatiha, where it is ayah 1 in its own right.
    if (i === 0 && m.number !== 1) {
      const fixed = stripBasmalaFragment(t);
      if (fixed) {
        if (!fixed.text) throw new Error(`surah ${m.number} ayah 1 is only a Basmala`);
        repairs.push(`${m.number}:1 stripped a Basmala fragment`);
        t = fixed.text;
      }
    }

    const out = { n: v.verse, t };
    if (sajdaAt.has(v.verse)) {
      out.s = 1;
      totalSajdas++;
    }
    return out;
  });

  totalAyahs += ayahs.length;

  // Metadata names read "<word for surah> <name>" — drop the leading word.
  const rawName = clean(m.name);
  const name = rawName.includes(' ') ? rawName.replace(/^\S+\s+/, '') : rawName;

  index.push({
    n: m.number,
    name,
    nameEn: m.englishName,
    ayahs: ayahs.length,
    type: m.revelationType === 'Meccan' ? MECCAN : MEDINAN,
  });

  fs.writeFileSync(
    path.join(OUT, `surah_${m.number}.json`),
    JSON.stringify({ n: m.number, name, ayahs })
  );
}

// Ship the Basmala alongside the index so the app never hardcodes it.
fs.writeFileSync(
  path.join(OUT, 'index.json'),
  JSON.stringify({ basmala: BASMALA, surahs: index })
);

console.log(`surahs: ${index.length}, ayahs: ${totalAyahs}, sajdas: ${totalSajdas}`);
repairs.forEach((r) => console.log(`repaired ${r}`));

// ---- Cross-source integrity check -------------------------------------
// Compare the consonantal skeleton of every generated ayah against the
// independent alquran.cloud text. The editions encode diacritics differently,
// so strip those and normalise letter variants; anything left is a real
// discrepancy in the scripture text itself.
const STRIP = new RegExp(
  '[' +
    '\\u0610-\\u061A' + // honorific signs
    '\\u064B-\\u065F' + // tanween, harakat, hamza marks
    '\\u0670' + // superscript alef
    '\\u06D6-\\u06ED' + // small high marks (rounded zero, dotless khah, …)
    '\\u08D3-\\u08FF' + // Arabic Extended-A marks (open tanween, …)
    '\\u0640' + // tatweel
    '\\u200B-\\u200F\\uFEFF' + // zero-width / direction marks
    ']',
  'g'
);

const skeleton = (s) =>
  s
    .replace(STRIP, '')
    .replace(/ٱ/g, 'ا') // alef wasla   -> alef
    .replace(/[آأإ]/g, 'ا') // آ أ إ -> alef
    .replace(/ى/g, 'ي') // alef maqsura -> ya
    .replace(/ؤ/g, 'و') // waw + hamza  -> waw
    .replace(/ئ/g, 'ي') // ya + hamza   -> ya
    .replace(/ة/g, 'ه') // ta marbuta   -> ha
    .replace(/ء/g, '') // standalone hamza
    .replace(/\s+/g, '');

const BASMALA_SKELETON = skeleton(BASMALA);
let checked = 0;
const mismatches = [];

for (const m of meta.surahs) {
  const built = JSON.parse(
    fs.readFileSync(path.join(OUT, `surah_${m.number}.json`), 'utf8')
  ).ayahs;

  for (let i = 0; i < built.length; i++) {
    let reference = skeleton(clean(m.ayahs[i].text));
    // The reference edition welds the Basmala onto ayah 1 of surahs 2..114.
    if (i === 0 && m.number !== 1 && reference.startsWith(BASMALA_SKELETON)) {
      reference = reference.slice(BASMALA_SKELETON.length);
    }
    checked++;
    if (skeleton(built[i].t) !== reference) {
      mismatches.push(`${m.number}:${built[i].n}`);
    }
  }
}

if (mismatches.length) {
  console.log(`\n✗ ${mismatches.length}/${checked} ayahs differ from the reference:`);
  console.log('  ' + mismatches.slice(0, 20).join(', ') + (mismatches.length > 20 ? ' …' : ''));
  process.exitCode = 1;
} else {
  console.log(`\n✓ all ${checked} ayahs match the independent reference text`);
}
