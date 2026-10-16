# Aletheia translation packs

Downloadable Bible texts for the Aletheia app. They are not bundled with the app: the app reads `packs/manifest.json`, then downloads the packs a reader picks from the Historically Significant Translations list and stores them on the device.

- `packs/bible/<id>.json`: Old and New Testament
- `packs/apoc/<id>.json`: Apocrypha
- `packs/dict/<id>.json`: dictionaries (`{ "meta": {...}, "entries": [ ["word", "<p>HTML entry</p>"], ... ] }`)
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
| lut | Martin Luther Translation 1545, German, 66 books. This is the Bolsinger text: Luther's 1545 Bible as printed by the Canstein Bible Institute, with modernized spelling and punctuation, not the original 1545 spelling. The source text has some scanning damage (missing umlauts such as Konig for König, some ß read as ft); search ignores accents, so König still finds it | CrossWire module GerBoLut 3.0. Public domain. |
| vulgate-clementine | Latin Vulgate, Clementine edition (1592), Latin, 66 books. Moved out of the app, which no longer ships it. Merged verses are marked with pointers | Clementine Vulgate Project / VulSearch (Michael Tweedale), base text Colunga and Turrado (Madrid, 1946), from open-bibles `lat-clementine.usfx.xml`. Public domain. Built by `build-clementine.ps1`. |
| jerome | Jerome Vulgate (405 CE), Latin, 66 books + Apocrypha. The Apocrypha has no Latin reference, so it is aligned to the English KJV Apocrypha by length and shared names (`-Idf`); Judith, Wisdom, Baruch and the Maccabees line up well, Tobit, Sirach and 2 Esdras may be off by a verse or more | CrossWire module Vulgate 2.1, from ccel.org. Public domain. Aligned verse for verse to the Clementine pack (`align.ps1 -RefTsv reports/clementine-bible.tsv`). |
| gothic | Gothic Bible of Wulfila (4th century): the Gospels (with gaps), Paul's letters to Philemon and part of Nehemiah, in Gothic script | CrossWire module Wulfila 1.0.1, from Project Wulfila (University of Antwerp), based on Streitberg's 1919 edition. Public domain text; the electronic text is free for non-commercial use with credit. Read by position in the verse index (`parse-sword.ps1 -KjvIndex`). |
| peshitta-ot | Syriac Old Testament (Peshitta, from the 2nd century), 39 books | ETCBC `peshitta` plain text 0.2 (github.com/ETCBC/peshitta; the Leiden Peshitta Institute text), MIT licence. The Syriac numbering is the Hebrew one, so `remap-mt.ps1` places each verse by the table `reports/mt-to-kjv.tsv`; a chapter is used only if its verse numbers are in the table (12 chapters are left out), and `gate-length.ps1` checks the placement against the Hebrew verse lengths (2 Chronicles 11 is left out). |
| peshitta-nt | Peshitta New Testament (5th century), Syriac | CrossWire module Peshitta 2.0: the British and Foreign Bible Society 1905 text. Public domain. |
| coptic-sahidic | Sahidic Coptic Bible (3rd century): the New Testament (no Jude) and the Old Testament books and chapters that survive (Psalms, most of the Pentateuch, Samuel, Job, Proverbs, Isaiah, Jeremiah ...) | CrossWire module CopSahBible2 1.3: INTF Digital Edition of the Coptic Old Testament and the Askeland / Schulz New Testament. **CC BY-SA 4.0.** Psalms are renumbered from the Greek numbers; other Old Testament chapters go through `remap-mt.ps1` and `gate-length.ps1` (against the Septuagint column). Verses lost to damage are simply missing. Parsed by `parse-cop.ps1`. |
| sinaiticus | Codex Sinaiticus (4th century), Greek: the New Testament and the Old Testament books it has (Psalms, Proverbs, Job, Isaiah, Jeremiah, the Twelve, parts of the Pentateuch and others) | The Codex Sinaiticus Project transcription v1.95 (github.com/itsee-birmingham/codex-sinaiticus). **CC BY-NC-SA 3.0**: non-commercial use only, with credit to the Codex Sinaiticus Project and under the same licence. First-hand readings; the lunate sigma is written as sigma. Parsed by `parse-sinaiticus.ps1`; aligned like the Coptic Old Testament. |
| wessex-gospels | West Saxon Gospels (c. 990), Old English: the four Gospels | Wikisource: Matthew (ed. J. W. Bright, 1910), Mark (Bright, 1905), Luke (a different edition, with the manuscript's wynn and yogh) and John (Bright and Harris, 1904, read from the proofread page scans). Text public domain, Wikisource transcription CC BY-SA 4.0. Parsed by `parse-wessex.ps1`. Missing: Matthew 4:15, 23:14, Luke 3:25-38 (the genealogy is not numbered in that edition), John 1:49 and 6:16 (not in the transcription). |
| textus-receptus | Textus Receptus, Scrivener's 1894 edition, Greek New Testament, accented and punctuated | [github.com/honza/textus-receptus](https://github.com/honza/textus-receptus) (data/gnt.flat.json; the greek_text of each verse). The authors give the data free of charge without any limitation on use and ask for credit. Already in KJV numbering (copy-aligned.ps1); read by parse-tr-honza.ps1. |
| douay-rheims-challoner | Douay-Rheims, Challoner revision (modernized spelling), 66 books + Apocrypha | Project Gutenberg #8300. Public domain. |
| kjv (apoc) | King James Version 1769, Apocrypha | eBible.org `eng-kjv`. Public domain (the KJV has a crown printing right in the UK only). |

## Rebuilding (PowerShell only)

1. Parse a source into `neutral/<id>.json` (the source's own numbering): `build-usfm.ps1` (USFM folders), `parse-douay.ps1`, `parse-wycliffe.ps1` (Wikisource pages), `parse-sword.ps1` (CrossWire zText modules), `parse-bishops.ps1` (JSON), 
2. `align.ps1 -Id <id>` (add `-Idf` when the source is not English, as for `lut`: rare character groups such as names count more, verses are matched one for one, and the Psalm titles that Luther numbers as verses are folded into verse 1) re-keys it to KJV numbering by comparing verse text (see `Aligner.cs`) and writes `aligned/<id>.json`; `reports/<id>-alignment.txt` lists every merge, split and dropped verse. Use `-RestrictToSourceChapters` for partly transcribed texts.
3. `assemble.ps1` writes `packs/` and `manifest.json`

`verify.ps1 -Id <id>` compares a translation's numbering with the KJV's.

## Modern language translations

The Bible's Texts page has a "Modern Language Translations" dropdown below "Historically Significant Translations". Greek, Hebrew and Latin are not in it (those languages have their own columns and downloads elsewhere).

| Pack | Content | Source and licence |
|---|---|---|
| ar-svd | Arabic, Smith and Van Dyck (1865), right to left | The Unbound Bible (bolls.life JSON). Public domain. |
| bn-irv | Bengali, Indian Revised Version (2018) | Bridge Connectivity Solutions. **CC BY-SA 4.0**, copyright 2018 Bridge Connectivity Solutions. |
| ceb-pinadayag | Cebuano, Pinadayag (1917) | CrossWire module CebPinadayag 1.0.1 (Zefania). Public domain. |
| zh-hans-cuv | Chinese Union Version, Simplified | MySword (Strong's numbers removed). Public domain. |
| zh-hant-cuv | Chinese Union Version, Traditional | MySword (Strong's numbers removed). Public domain. |
| fr-segond | French, Louis Segond (1910) | MySword. Public domain. |
| de-elberfelder | German, Elberfelder (1905) | The Unbound Bible. Public domain. (The source text has a few missing spaces before "über", e.g. "warüber".) |
| hi-irv | Hindi, Indian Revised Version (2019) | Bridge Connectivity Solutions. **CC BY-SA 4.0**, copyright 2017/2018 Bridge Connectivity Solutions. |
| ja-kougo | Japanese, Kougo-yaku (1955), complete (furigana removed) | bolls.life `JPKJV`. Public domain (copyright expired 2006). The text marks every verse that is numbered differently from the English Bible with the English verse in square brackets; `map-ja-markers.ps1` reads those markers, so its verse numbers are exact. |
| ko-krv | Korean Revised Version (1961), complete | bolls.life `KRV`. Listed as public domain by its source, but the Korean Bible Society states a 1961 copyright, so check before relying on it. (The Unbound Bible Korean file first used had 173 verses missing.) |
| pt-almeida | Portuguese, Almeida Revista e Corrigida | WordProject text, corrected for European Portuguese spelling; listed as public domain by the source. |
| ru-synodal | Russian, Synodal Translation (1876), 66 books | CrossWire module RusSynodal 1.9.1. Public domain. The Apocrypha is not published (Cyrillic cannot be matched to the English KJV Apocrypha). The module uses Greek psalm numbers, converted to Hebrew ones here. |
| es-rv1909 | Spanish, Reina-Valera (1909) | American Bible Society text with Strong's numbers (removed). Public domain. |
| tl-ab | Tagalog, Ang Biblia | MySword, typed from the Philippine Bible Society text. Public domain. |

Most of these files already use the KJV chapter and verse numbers, so `copy-aligned.ps1` copies them (verses a text leaves out simply stay empty). Texts that differ in a few places (`bn-irv`, `hi-irv`, `es-rv1909`, `ru-synodal`) go through `align.ps1 -Idf -KeyBonus 0.5 -ChapterBlocks`, which aligns only the chapters whose verse numbers differ (and their neighbours). A verse that has no KJV counterpart is added to the end of the verse before it. `reports/<id>-alignment.txt` lists each change. Where Latin letters are not shared with English (Russian) only verse length guides the alignment, so a few verses in Job (and any chapter that is not numbered like the KJV) may be off by a verse or more.

The Cebuano and Russian modules come from CrossWire. `parse-sword.ps1 -KjvIndex` reads a module that has no book and chapter markers by position, and `parse-bolls.ps1` reads the JSON files (books numbered 1 to 66, one verse per row).

What the app does for these texts: the column carries the `lang` tag (correct Chinese, Japanese and Korean glyph forms) and Arabic columns read right to left. Search folds accents, Arabic vowel marks and old letter forms but keeps the vowel signs of Indic scripts, and treats each Chinese or Japanese character as a search term, so a typed word is found as a phrase of characters.

## Re-checking the alignment

All older packs were re-aligned with the current scripts. Results: Geneva, Bishops, Tyndale and Luther came out unchanged. Wycliffe and Douay-Rheims (Vulgate psalm numbers) now convert the Psalms to the Hebrew numbering first (as the Russian pack does), fold each Psalm title into verse 1 and align chapter by chapter, which fixes titles that had attached to the end of the previous psalm. A source verse with no KJV match now joins the verse before it instead of being lost. The BSB and NRSVue (built into the app, not published here) use -ChapterBlocks -GapsOnly: a verse is matched by its number, so a verse the source leaves out stays empty. This fixed NRSVue Psalm 119, which had been spread over the wrong verses; the NRSVue source file itself stops at Psalm 119:100 and lacks verses 101 to 176.

## Dictionaries

| Pack | Content | Source and licence |
|---|---|---|
| webster1828 | Noah Webster, *An American Dictionary of the English Language* (1828), 62,391 entries | `webster1828.csv` from [akaitsurugi/webster1828](https://github.com/akaitsurugi/webster1828), a typed copy of the 1828 edition checked against the archive.org scans. The 1828 text is public domain; the CSV is **CC BY-SA 4.0** (credit: akaitsurugi/webster1828). Built by `build-webster.ps1`. |

The app does not keep this as a pack: it stores the entries in its search database (in pieces) so the Search tab can search them. 1828dictionary.com refuses automated downloads (it answers HTTP 403), so it was not used as the source.

Wiktionary (Modern) is not a pack: the app asks Wiktionary's web service for each look-up and keeps only the last five.

## Texts looked for and not found

- **Codex Vaticanus, Codex Alexandrinus, Codex Ephraemi Rescriptus**: no free, complete transcription could be downloaded (the Alexandrinus copy on archive.org is CC BY-NC-ND, which forbids a derivative; the INTF transcripts have no bulk download and no clear licence). The slots are in the app marked "Coming soon".
- **Old English Hexateuch**: only an OCR scan of Crawford's 1922 edition exists, and the work is a paraphrase of Genesis to Joshua that does not follow the verses.
- **The Great Bible (1539)**: a partial pack (about 45% of the Bible) was published earlier from textusreceptusbibles.com. That site's Terms of Use allow downloads for personal use only and do not allow its text to be stored on another site or in an app without written permission, so the pack has been withdrawn and its slot in the app shows "Coming soon". It can return if MasonSoft Technology Ltd gives written permission, or from another source.
