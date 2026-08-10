/**
 * Bundles the three short hadith collections that ship with the app.
 *
 * Only the "forty" collections are bundled: together they are about 110 KB,
 * where Bukhari and Muslim alone would add 18 MB. The large collections are
 * fetched on demand instead, the same way the longer tafsirs are.
 *
 * All of these are classical works long out of copyright.
 */
const fs = require('fs');
const path = require('path');

const OUT = process.argv[2];
if (!OUT) throw new Error('usage: node build_library.js <outDir>');

const BOOKS = [
  { id: 'nawawi', file: 'h_ara-nawawi.json', expect: 42 },
  { id: 'qudsi', file: 'h_ara-qudsi.json', expect: 40 },
  { id: 'dehlawi', file: 'h_ara-dehlawi.json', expect: 40 },
];

fs.mkdirSync(OUT, { recursive: true });

const problems = [];
let total = 0;

for (const book of BOOKS) {
  const raw = JSON.parse(fs.readFileSync(book.file, 'utf8'));
  const sections = raw.metadata?.sections ?? {};

  const hadiths = [];
  for (const h of raw.hadiths ?? []) {
    const text = String(h.text ?? '').trim();
    if (!text) {
      problems.push(`${book.id}: hadith ${h.hadithnumber} is empty`);
      continue;
    }
    const entry = { n: h.hadithnumber, t: text };
    // Gradings are only meaningful for the sunan; the forty collections carry
    // none, so the field is omitted rather than left blank.
    const grade = (h.grades ?? []).map((g) => g.grade).filter(Boolean)[0];
    if (grade) entry.g = grade;
    hadiths.push(entry);
  }

  if (hadiths.length !== book.expect) {
    problems.push(
      `${book.id}: ${hadiths.length} hadiths, expected ${book.expect}`
    );
  }
  total += hadiths.length;

  fs.writeFileSync(
    path.join(OUT, `${book.id}.json`),
    JSON.stringify({
      id: book.id,
      sections: Object.fromEntries(
        Object.entries(sections).filter(([k, v]) => k !== '0' && v)
      ),
      hadiths,
    })
  );
}

const bytes = fs
  .readdirSync(OUT)
  .reduce((sum, f) => sum + fs.statSync(path.join(OUT, f)).size, 0);

console.log(`books: ${BOOKS.length}`);
console.log(`hadiths: ${total}`);
console.log(`on disk: ${(bytes / 1024).toFixed(0)} KB`);

if (problems.length) {
  console.log(`\n✗ ${problems.length} problem(s):`);
  problems.forEach((p) => console.log('  ' + p));
  process.exitCode = 1;
} else {
  console.log('\n✓ every bundled book is complete and free of empty entries');
}
