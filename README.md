# Aletheia translation packs

Downloadable Bible texts for the Aletheia app. They are not bundled with the app: the app reads `packs/manifest.json`, then downloads the packs a reader picks from the Historically Significant Translations list and stores them on the device.

- `packs/bible/<id>.json`: Old and New Testament
- `packs/apoc/<id>.json`: Apocrypha
- `packs/manifest.json`: every pack with its size and SHA-256 checksum

Pack layout: `{ "meta": {...}, "books": { "<book id>": { "<chapter>": { "<verse>": "text" } } } }`.
Book ids are the app's (`gen`, `1sam`, `matt`, ... and `tob`, `wis`, `1macc`, ...).
All verse numbers follow the KJV numbering the app uses, so columns line up. A verse whose text is `^N` is included in verse N of the same translation (the source merges the two). A pack may cover only some books; the manifest lists them.

## Packs

| Pack | Content | Source and licence |
|---|---|---|
| geneva | Geneva Bible 1599, original spelling, 66 books | eBible.org `enggnv`. Public domain. |
| bishops | Bishops' Bible 1568, original spelling, 66 books (no Apocrypha) | supplied file `bishops.json`. Public domain. |
| wycliffe | Wycliffe Bible, Later Version, Middle English, 66 books + Apocrypha | CrossWire module Wycliffe 2.4.1, built from the Wikisource transcription ([Bible (Wycliffe)](https://en.wikisource.org/wiki/Bible_(Wycliffe))). The text is public domain; the module and transcription are **CC BY-SA 4.0** (Wikisource contributors, CrossWire). |
| tyndale | Tyndale 1525 New Testament and 1530 Pentateuch and Jonah, original spelling | CrossWire module Tyndale 2.1, from Wikisource ([Bible (Tyndale)](https://en.wikisource.org/wiki/Bible_(Tyndale))). Public domain. |
| great | The Great Bible 1539, original spelling. **Partial**: about 45% of the Bible (Genesis, Exodus, Joshua, 2 Kings, Esther, Ezekiel, Matthew, Mark, 1 and 2 Corinthians, Galatians and Ephesians are complete; other books partly or not at all) | textusreceptus.thekingsbible.com, which transcribes it chapter by chapter and shows no licence for its transcription. The 1539 text itself is public domain. |
| lut | Martin Luther Translation 1545, German, 66 books. This is the Bolsinger text: Luther's 1545 Bible as printed by the Canstein Bible Institute, with modernized spelling and punctuation, not the original 1545 spelling. The source text has some scanning damage (missing umlauts such as Konig for König, some ß read as ft); search ignores accents, so König still finds it | CrossWire module GerBoLut 3.0. Public domain. |
| douay-rheims-challoner | Douay-Rheims, Challoner revision (modernized spelling), 66 books + Apocrypha | Project Gutenberg #8300. Public domain. |
| kjv (apoc) | King James Version 1769, Apocrypha | eBible.org `eng-kjv`. Public domain (the KJV has a crown printing right in the UK only). |

## Rebuilding (PowerShell only)

1. Parse a source into `neutral/<id>.json` (the source's own numbering): `build-usfm.ps1` (USFM folders), `parse-douay.ps1`, `parse-wycliffe.ps1` (Wikisource pages), `parse-sword.ps1` (CrossWire zText modules), `parse-bishops.ps1` (JSON), `fetch-great.ps1` then `parse-great.ps1` (web pages)
2. `align.ps1 -Id <id>` (add `-Idf` when the source is not English, as for `lut`: rare character groups such as names count more, verses are matched one for one, and the Psalm titles that Luther numbers as verses are folded into verse 1) re-keys it to KJV numbering by comparing verse text (see `Aligner.cs`) and writes `aligned/<id>.json`; `reports/<id>-alignment.txt` lists every merge, split and dropped verse. Use `-RestrictToSourceChapters` for partly transcribed texts.
3. `assemble.ps1` writes `packs/` and `manifest.json`

`verify.ps1 -Id <id>` compares a translation's numbering with the KJV's.

## Modern language translations (slots ready, files to come)

The Bible's Texts page has a "Modern Language Translations" dropdown below "Medieval English Translations". It lists these slots, sorted by English name, all marked "Coming soon" until a file is published:

| Slot id | Language | Script and direction | `lang` tag |
|---|---|---|---|
| `ar` | Arabic | Arabic, right to left | `ar` |
| `zh-hans` | Chinese Simplified | Han | `zh-Hans` |
| `zh-hant` | Chinese Traditional | Han | `zh-Hant` |
| `fr` | French | Latin | `fr` |
| `de` | German | Latin | `de` |
| `el` | Greek | Greek | `el` |
| `he` | Hebrew | Hebrew, right to left | `he` |
| `ja` | Japanese | Han and kana | `ja` |
| `ko` | Korean | Hangul | `ko` |
| `la` | Latin | Latin (the Clementine Vulgate already ships in the app; this slot is for another Latin text) | `la` |
| `pt` | Portuguese | Latin | `pt` |
| `ru` | Russian | Cyrillic | `ru` |
| `es` | Spanish | Latin | `es` |

The Greek and Hebrew slots are for modern translations; the app's own original-language columns (SBL Greek New Testament, Westminster Leningrad Codex, Septuagint) are separate.

To publish one: parse the file into `neutral/<id>.json` (see "Rebuilding"), run `align.ps1`, run `assemble.ps1`, push, then in the app's `PK_CATALOG` (index.html) give the slot the translation's own `label` and `sub` and set `available: true`. If a language gets a second translation, add a second entry with its own id (the dropdown sorts by label).

What the app already does for these texts: the column carries the `lang` tag (correct Chinese, Japanese and Korean glyph forms) and Arabic columns read right to left. Search folds accents, Arabic vowel marks and old letter forms, and treats each Chinese or Japanese character as a search term, so a typed word is found as a phrase of characters.