/**
 * Downloads one tafsir edition into its own directory, keyed by ayah.
 *
 * Validates against the bundled Quran index so a short or misaligned download
 * fails loudly instead of shipping gaps.
 *
 * usage: node fetch_tafsir_edition.js <editionSlug> <outDir> <quranAssetsDir>
 */
const fs = require('fs');
const path = require('path');

const [edition, OUT, QURAN] = process.argv.slice(2);
if (!edition || !OUT || !QURAN) {
  throw new Error('usage: node fetch_tafsir_edition.js <slug> <outDir> <quranDir>');
}

const BASE = `https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/${edition}`;

const index = JSON.parse(
  fs.readFileSync(path.join(QURAN, 'index.json'), 'utf8')
).surahs;

fs.mkdirSync(OUT, { recursive: true });

async function fetchSurah(n, attempt = 1) {
  try {
    const res = await fetch(`${BASE}/${n}.json`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    if (attempt >= 3) throw new Error(`surah ${n}: ${e.message}`);
    await new Promise((r) => setTimeout(r, 500 * attempt));
    return fetchSurah(n, attempt + 1);
  }
}

(async () => {
  const problems = [];
  let entries = 0;
  let chars = 0;

  const queue = index.slice();
  const workers = Array.from({ length: 6 }, async () => {
    while (queue.length) {
      const info = queue.shift();
      const raw = await fetchSurah(info.n);
      if (!Array.isArray(raw)) {
        problems.push(`surah ${info.n}: expected an array`);
        continue;
      }

      const byAyah = {};
      for (const item of raw) {
        const ayah = item.ayah ?? item.verse ?? item.aya;
        const text = (item.text ?? '').trim();
        if (!ayah || !text) continue;
        byAyah[ayah] = text;
        chars += text.length;
      }

      const have = Object.keys(byAyah).length;
      entries += have;
      if (have !== info.ayahs) {
        problems.push(
          `surah ${info.n} (${info.nameEn}): ${have} entries for ${info.ayahs} ayahs`
        );
      }

      fs.writeFileSync(path.join(OUT, `${info.n}.json`), JSON.stringify(byAyah));
    }
  });

  await Promise.all(workers);

  const bytes = fs
    .readdirSync(OUT)
    .reduce((sum, f) => sum + fs.statSync(path.join(OUT, f)).size, 0);

  console.log(`edition: ${edition}`);
  console.log(`entries: ${entries} (expected 6236)`);
  console.log(`text: ${(chars / 1024 / 1024).toFixed(2)} MB`);
  console.log(`on disk: ${(bytes / 1024 / 1024).toFixed(2)} MB`);

  if (problems.length) {
    console.log(`\n✗ ${problems.length} coverage gap(s):`);
    problems.slice(0, 10).forEach((p) => console.log('  ' + p));
    process.exitCode = 1;
  } else {
    console.log('\n✓ every ayah in all 114 surahs has tafsir');
  }
})();
