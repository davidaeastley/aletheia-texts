# Aletheia translation packs

Downloadable Bible texts for the Aletheia app. They are not bundled with the app: the app reads `packs/manifest.json`, then downloads the packs a reader picks and stores them on the device.

- `packs/bible/<id>.json`: Old and New Testament
- `packs/apoc/<id>.json`: Apocrypha
- `packs/manifest.json`: every pack with its size and SHA-256 checksum

Pack layout: `{ "meta": {...}, "books": { "<book id>": { "<chapter>": { "<verse>": "text" } } } }`.
Book ids are the app's (`gen`, `1sam`, `matt`, ... and `tob`, `wis`, `1macc`, ...).
All verse numbers follow the KJV numbering the app uses, so columns line up. A verse whose text is `^N` is included in verse N of the same translation (the source merges the two).

## Packs

| Pack | Content | Source |
|---|---|---|
| geneva | Geneva Bible 1599, original spelling | eBible.org `enggnv` |
| wycliffe | Wycliffe Bible, Later Version, Middle English, 66 books + Apocrypha | Wikisource, "Bible (Wycliffe)" (transcription by Wikisource contributors) |
| tyndale | Tyndale New Testament 1534, original spelling | eBible.org `engtnt` |
| douay-rheims-challoner | Douay-Rheims, Challoner revision (modernized spelling), 66 books + Apocrypha | Project Gutenberg #8300 |
| kjv (apoc) | King James Version 1769, Apocrypha | eBible.org `eng-kjv` |

All texts are public domain. (The KJV is subject to a crown/letters-patent printing right in the UK only.)

## Rebuilding (PowerShell only)

1. Parse a source into `neutral/<id>.json` (the source's own numbering): `build-usfm.ps1` (USFM folders), `parse-douay.ps1`, `parse-wycliffe.ps1`
2. `align.ps1 -Id <id>` re-keys it to KJV numbering by comparing verse text (see `Aligner.cs`) and writes `aligned/<id>.json`; `reports/<id>-alignment.txt` lists every merge, split and dropped verse
3. `assemble.ps1` writes `packs/` and `manifest.json`

`verify.ps1 -Id <id>` compares a translation's numbering with the KJV's.