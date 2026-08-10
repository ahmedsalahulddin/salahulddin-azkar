/**
 * Builds the Mushaf page index: which ayahs sit on each of the 604 pages of
 * the Madinah Mushaf, plus the juz each page belongs to.
 *
 * Page/juz numbering comes from the alquran.cloud dump; the text itself is
 * already bundled per surah, so pages only need to reference ranges.
 */
const fs = require('fs');
const path = require('path');

const OUT = process.argv[2];
if (!OUT) throw new Error('usage: node build_pages.js <quranAssetsDir>');

const meta = JSON.parse(fs.readFileSync('quran_raw.json', 'utf8')).data;

// page -> ordered list of contiguous {surah, first, last} runs
const pages = new Map();

for (const s of meta.surahs) {
  for (const a of s.ayahs) {
    const page = a.page;
    if (!page) throw new Error(`ayah ${s.number}:${a.numberInSurah} has no page`);

    if (!pages.has(page)) pages.set(page, { juz: a.juz, runs: [] });
    const entry = pages.get(page);
    const last = entry.runs[entry.runs.length - 1];

    // Extend the current run when the same surah continues on this page.
    if (last && last.s === s.number && last.l === a.numberInSurah - 1) {
      last.l = a.numberInSurah;
    } else {
      entry.runs.push({ s: s.number, f: a.numberInSurah, l: a.numberInSurah });
    }
  }
}

const numbers = [...pages.keys()].sort((a, b) => a - b);
if (numbers.length !== 604) throw new Error(`expected 604 pages, got ${numbers.length}`);
for (let i = 0; i < numbers.length; i++) {
  if (numbers[i] !== i + 1) throw new Error(`page numbering breaks at ${numbers[i]}`);
}

const out = numbers.map((p) => ({
  p,
  j: pages.get(p).juz,
  r: pages.get(p).runs,
}));

fs.writeFileSync(path.join(OUT, 'pages.json'), JSON.stringify(out));

// ---- Validation: every ayah must appear exactly once across all pages ----
const seen = new Set();
let counted = 0;
for (const page of out) {
  for (const run of page.r) {
    if (run.f > run.l) throw new Error(`page ${page.p}: inverted run`);
    for (let a = run.f; a <= run.l; a++) {
      const key = `${run.s}:${a}`;
      if (seen.has(key)) throw new Error(`ayah ${key} appears on more than one page`);
      seen.add(key);
      counted++;
    }
  }
}

const expected = meta.surahs.reduce((sum, s) => sum + s.ayahs.length, 0);
const size = fs.statSync(path.join(OUT, 'pages.json')).size;

console.log(`pages: ${out.length}`);
console.log(`runs: ${out.reduce((sum, p) => sum + p.r.length, 0)}`);
console.log(`size: ${(size / 1024).toFixed(0)} KB`);
console.log(
  counted === expected
    ? `\n✓ all ${counted} ayahs mapped exactly once across 604 pages`
    : `\n✗ mapped ${counted} ayahs but the Quran has ${expected}`
);
if (counted !== expected) process.exitCode = 1;
