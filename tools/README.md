# tools

Scripts that produced everything under `assets/`. The generated assets are
committed, so a normal build needs none of this — these exist so the data can be
rebuilt, audited, or refreshed from source.

Each script validates what it produces and exits non-zero on a gap, rather than
writing a file that only looks right.

Run them from a scratch directory holding the downloaded source dumps.

| Script | Produces | Source |
|---|---|---|
| `build_quran_assets.js` | `assets/quran/surah_*.json`, `index.json` | KFGQPC Uthmanic Hafs, cross-checked against a second edition |
| `build_pages.js` | `assets/quran/pages.json` | Madinah Mushaf page/juz mapping (604 pages) |
| `build_ayah_boxes.js` | `assets/quran/ayah_boxes.json` | Glyph coordinate database, for tapping an ayah on the page image |
| `fetch_tafsir_edition.js` | `assets/tafsir/<edition>/` | tafsir_api |
| `fetch_hisn.js` | `assets/adhkar/hisn.json` | hisnmuslim.com developer API |
| `build_library.js` | `assets/books/*.json` | hadith-api |
| `match_audio.js` | the audio map inlined in `lib/data/adhkar_data.dart` | matches the app's own adhkar to Hisn recitations |

## Things worth knowing before touching these

- **Never hand-type Arabic from these datasets** into Dart, tests, or a script.
  Retyped text does not round-trip to the same code points — the Basmala and the
  surah names both broke this way. Read the value out of the data instead.
- **`match_audio.js` only accepts exact matches.** Substring and prefix
  similarity were tried and linked the tahlil to the whole morning
  supplication, Al-Falaq to Al-Ikhlas, and the evening supplication to its
  morning counterpart. Playing the wrong dua is worse than none, so the
  threshold stays at exact.
- The Quran text needs the bundled **Amiri Quran** font: it uses Arabic
  Extended-A marks (U+08F0–U+08F2) that most system fonts lack, and without the
  font thousands of ayahs render as empty boxes.
