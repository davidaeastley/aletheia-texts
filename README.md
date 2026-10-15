# Aletheia translation packs

Downloadable Bible texts for the Aletheia app. They are not bundled with the app: the app reads `packs/manifest.json`, then downloads the packs a reader picks and stores them on the device.

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
| douay-rheims-challoner | Douay-Rheims, Challoner revision (modernized spelling), 66 books + Apocrypha | Project Gutenberg #8300. Public domain. |
| kjv (apoc) | King James Version 1769, Apocrypha | eBible.org `eng-kjv`. Public domain (the KJV has a crown printing right in the UK only). |

## Rebuilding (PowerShell only)

1. Parse a source into `neutral/<id>.json` (the source's own numbering): `build-usfm.ps1` (USFM folders), `parse-douay.ps1`, `parse-wycliffe.ps1` (Wikisource pages), `parse-sword.ps1` (CrossWire zText modules), `parse-bishops.ps1` (JSON), `fetch-great.ps1` then `parse-great.ps1` (web pages)
2. `align.ps1 -Id <id>` re-keys it to KJV numbering by comparing verse text (see `Aligner.cs`) and writes `aligned/<id>.json`; `reports/<id>-alignment.txt` lists every merge, split and dropped verse. Use `-RestrictToSourceChapters` for partly transcribed texts.
3. `assemble.ps1` writes `packs/` and `manifest.json`

`verify.ps1 -Id <id>` compares a translation's numbering with the KJV's.
