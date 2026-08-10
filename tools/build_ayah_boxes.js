/**
 * Turns the glyph-level coordinate database into per-page ayah boxes, so a tap
 * on the Mushaf image can be resolved to an ayah and that ayah highlighted.
 *
 * Glyphs are merged per (page, surah, ayah, line): one ayah usually spans a few
 * lines, and each line becomes one rectangle. Coordinates stay in the source
 * image's pixel space (reference width 1024); the reader scales them by the
 * intrinsic size of the image it actually loaded.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DB = 'ayahinfo_1024.db';
const REFERENCE_WIDTH = 1024;

const OUT = process.argv[2];
if (!OUT) throw new Error('usage: node build_ayah_boxes.js <quranAssetsDir>');

const rows = execFileSync(
  'sqlite3',
  [
    DB,
    '-separator', '\t',
    `SELECT page_number, sura_number, ayah_number, line_number,
            MIN(min_x), MAX(max_x), MIN(min_y), MAX(max_y)
     FROM glyphs
     GROUP BY page_number, sura_number, ayah_number, line_number
     ORDER BY page_number, sura_number, ayah_number, line_number`,
  ],
  { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }
).trim().split('\n');

// page -> ayah key -> boxes
const pages = new Map();
let boxCount = 0;

for (const line of rows) {
  const [page, sura, ayah, , minX, maxX, minY, maxY] = line.split('\t').map(Number);
  if (!pages.has(page)) pages.set(page, new Map());
  const key = `${sura}:${ayah}`;
  const byAyah = pages.get(page);
  if (!byAyah.has(key)) byAyah.set(key, { s: sura, a: ayah, b: [] });
  byAyah.get(key).b.push([minX, minY, maxX, maxY]);
  boxCount++;
}

const out = { w: REFERENCE_WIDTH, pages: {} };
for (const [page, byAyah] of pages) {
  out.pages[page] = [...byAyah.values()];
}

fs.writeFileSync(path.join(OUT, 'ayah_boxes.json'), JSON.stringify(out));
const size = fs.statSync(path.join(OUT, 'ayah_boxes.json')).size;

// ---- Validation -------------------------------------------------------
const problems = [];
const covered = new Set();

for (const [page, byAyah] of pages) {
  if (page < 1 || page > 604) problems.push(`page ${page} out of range`);
  for (const entry of byAyah.values()) {
    covered.add(`${entry.s}:${entry.a}`);
    for (const [x1, y1, x2, y2] of entry.b) {
      if (x1 >= x2 || y1 >= y2) {
        problems.push(`page ${page} ${entry.s}:${entry.a} has an empty box`);
      }
      if (x1 < 0 || x2 > REFERENCE_WIDTH) {
        problems.push(`page ${page} ${entry.s}:${entry.a} runs outside the image`);
      }
    }
  }
}

console.log(`pages with boxes: ${pages.size}`);
console.log(`ayahs covered: ${covered.size}`);
console.log(`boxes: ${boxCount}`);
console.log(`size: ${(size / 1024).toFixed(0)} KB`);

if (problems.length) {
  console.log(`\n✗ ${problems.length} problem(s):`);
  problems.slice(0, 10).forEach((p) => console.log('  ' + p));
  process.exitCode = 1;
} else if (pages.size !== 604 || covered.size !== 6236) {
  console.log(`\n✗ expected 604 pages and 6236 ayahs`);
  process.exitCode = 1;
} else {
  console.log('\n✓ all 604 pages and 6236 ayahs have valid boxes');
}
