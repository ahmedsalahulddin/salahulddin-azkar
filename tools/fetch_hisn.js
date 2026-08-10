/**
 * Downloads Hisn al-Muslim (حصن المسلم) from the publisher's own developer API
 * at hisnmuslim.com and writes it as a single bundled asset.
 *
 * Fails loudly on any empty chapter or blank dhikr rather than shipping gaps.
 */
const fs = require('fs');
const path = require('path');

const BASE = 'https://www.hisnmuslim.com/api/ar';
const OUT = process.argv[2];
if (!OUT) throw new Error('usage: node fetch_hisn.js <outFile>');

const stripBom = (s) => s.replace(/^﻿/, '');

async function getJson(url, attempt = 1) {
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return JSON.parse(stripBom(await res.text()));
  } catch (e) {
    if (attempt >= 3) throw new Error(`${url}: ${e.message}`);
    await new Promise((r) => setTimeout(r, 600 * attempt));
    return getJson(url, attempt + 1);
  }
}

(async () => {
  const rawIndex = await getJson(`${BASE}/husn_ar.json`);
  const listing = rawIndex[Object.keys(rawIndex)[0]];
  console.log(`chapters listed: ${listing.length}`);

  const chapters = new Array(listing.length);
  const problems = [];
  let totalItems = 0;

  const queue = listing.map((c, i) => ({ c, i }));
  const workers = Array.from({ length: 8 }, async () => {
    while (queue.length) {
      const { c, i } = queue.shift();
      const title = String(c.TITLE).trim();
      const body = await getJson(`${BASE}/${c.ID}.json`);
      const items = body[Object.keys(body)[0]];

      if (!Array.isArray(items) || items.length === 0) {
        problems.push(`chapter ${c.ID} (${title}): no items`);
        continue;
      }

      const cleaned = [];
      for (const it of items) {
        const text = String(it.ARABIC_TEXT ?? '').trim();
        if (!text) {
          problems.push(`chapter ${c.ID} (${title}): blank dhikr`);
          continue;
        }
        const repeat = Number(it.REPEAT) || 1;

        // Recitation is published per dhikr. Only the id is stored — the URL
        // is rebuilt at runtime, which keeps the bundled file small.
        const audio = String(it.AUDIO ?? '');
        const match = audio.match(/\/(\d+)\.mp3$/);
        if (audio && !match) {
          problems.push(`chapter ${c.ID}: unexpected audio URL "${audio}"`);
        }

        const entry = { n: cleaned.length + 1, t: text, r: repeat };
        if (match) entry.au = Number(match[1]);
        cleaned.push(entry);
      }

      totalItems += cleaned.length;
      // Keep the publisher's own ordering.
      chapters[i] = { id: c.ID, title, items: cleaned };
    }
  });

  await Promise.all(workers);

  const ordered = chapters.filter(Boolean);
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify({ chapters: ordered }));

  const bytes = fs.statSync(OUT).size;
  console.log(`chapters written: ${ordered.length}`);
  console.log(`adhkar: ${totalItems}`);
  console.log(`size: ${(bytes / 1024).toFixed(0)} KB`);

  if (problems.length) {
    console.log(`\n✗ ${problems.length} problem(s):`);
    problems.slice(0, 15).forEach((p) => console.log('  ' + p));
    process.exitCode = 1;
  } else {
    console.log('\n✓ every chapter has at least one dhikr, none blank');
  }
})();
