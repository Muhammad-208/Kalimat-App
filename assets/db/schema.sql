-- Kalimat offline database schema (v1)
-- Produced by the Python pipeline (build_quran_db.py + build_furuq.py),
-- then shipped as assets/db/kalimat.db and copied to app storage on first run.
--
-- The app opens this READ-ONLY. All editing happens in the separate
-- editor/admin workflow, which re-exports a new versioned kalimat.db.

PRAGMA foreign_keys = ON;

-- ── ROOTS ────────────────────────────────────────────────────────────
-- One row per triliteral (or quadriliteral) root.
CREATE TABLE roots (
  root_id      INTEGER PRIMARY KEY,
  root         TEXT NOT NULL UNIQUE,   -- "بحر"
  root_spaced  TEXT NOT NULL,          -- "ب ح ر"  (display)
  root_norm    TEXT NOT NULL DEFAULT '', -- normalize(root): no tashkeel, unified hamza/alef
  root_fuzzy   TEXT NOT NULL DEFAULT '', -- collapse_doubles(root_norm): ربب -> رب
  freq         INTEGER NOT NULL DEFAULT 0, -- total Quranic occurrences (42)

  -- Pre-generated, human-reviewed content (never live-LLM):
  simple       TEXT,                   -- الشرح المبسّط
  maqayis      TEXT,                   -- المعنى المحوري — Ibn Faris
  semitic      TEXT,                   -- المقابل السامي (nullable; disputed)
  semitic_note TEXT                    -- e.g. "cf. Proto-Semitic *b-ḥ-r (?)"
);
CREATE INDEX idx_roots_root ON roots(root);
CREATE INDEX idx_roots_freq ON roots(freq DESC);
CREATE INDEX idx_roots_norm ON roots(root_norm);
CREATE INDEX idx_roots_fuzzy ON roots(root_fuzzy);

-- ── SOURCES CATALOG ──────────────────────────────────────────────────
-- One row per work you draw from, so attributions/licenses stay clean as
-- the number of sources grows (this is what keeps it "جامع" organized).
CREATE TABLE sources (
  source_id  INTEGER PRIMARY KEY,
  name       TEXT NOT NULL,            -- "لسان العرب"
  author     TEXT,                     -- "ابن منظور"
  death_year TEXT,                     -- "711هـ"
  category   TEXT NOT NULL,            -- 'dictionary' | 'quran_lexicon'
                                       -- | 'furuq' | 'semitic' | 'grammar'
  edition    TEXT,                     -- the specific digital edition (for rights)
  license    TEXT                      -- 'public-domain' | 'OFL' | 'GPL' | ...
);

-- ── LEXICON ENTRIES ──────────────────────────────────────────────────
-- Classical dictionary quotations per root (al-Raghib, Lisan al-Arab, ...).
-- Add as MANY sources per root as you like — the app lists them all.
CREATE TABLE lexicon_entries (
  entry_id  INTEGER PRIMARY KEY,
  root_id   INTEGER NOT NULL REFERENCES roots(root_id),
  source    TEXT NOT NULL,             -- display name "الراغب الأصفهاني"
  category  TEXT,                      -- lets the UI group معاجم عامة / قرآنية
  ordinal   INTEGER NOT NULL DEFAULT 0,
  body      TEXT NOT NULL
);
CREATE INDEX idx_lex_root ON lexicon_entries(root_id, ordinal);

-- ── WORDS / OCCURRENCES ──────────────────────────────────────────────
-- Every surface form of a root as it appears in the Quran.
CREATE TABLE words (
  word_id   INTEGER PRIMARY KEY,
  root_id   INTEGER NOT NULL REFERENCES roots(root_id),
  surface   TEXT NOT NULL,             -- "الْبَحْرَ"  (vocalized, for display)
  surface_norm TEXT NOT NULL DEFAULT '', -- normalize(surface): "البحر" (for search)
  surah     INTEGER NOT NULL,
  ayah      INTEGER NOT NULL,
  position  INTEGER,                   -- token index within the ayah
  verse_text TEXT                      -- legacy/optional; ayah text now lives in `ayahs`
);
CREATE INDEX idx_words_root ON words(root_id);
CREATE INDEX idx_words_loc  ON words(surah, ayah);
CREATE INDEX idx_words_surface ON words(surface);
CREATE INDEX idx_words_surface_norm ON words(surface_norm);

-- ── SEARCH KEYS ──────────────────────────────────────────────────────
-- Precomputed lookup keys mapping what a user might TYPE to a root.
-- Quranic orthography differs from how people type: dagger-alef for long ā
-- (ٱلْكِتَٰب vs الكتاب), waw-spelled صلوة vs الصلاة, and attached prefixes
-- (وَٱلْبَحْر vs بحار). One row per (kind, key); the most frequent root wins.
--   kind 0 = normalized spelling variant  (high confidence)
--   kind 1 = consonantal skeleton, long vowels dropped (lossy fallback)
CREATE TABLE word_keys (
  kind    INTEGER NOT NULL,
  key     TEXT NOT NULL,
  root_id INTEGER NOT NULL REFERENCES roots(root_id),
  PRIMARY KEY (kind, key)
) WITHOUT ROWID;

-- Surah reference (for grouping the "all occurrences" screen).
CREATE TABLE surahs (
  surah  INTEGER PRIMARY KEY,
  name   TEXT NOT NULL                 -- "البقرة"
);

-- Full ayah text, stored once per verse (NOT duplicated per word, which would
-- bloat the shipped DB by ~10MB). Joined in when rendering a verse card.
CREATE TABLE ayahs (
  surah  INTEGER NOT NULL,
  ayah   INTEGER NOT NULL,
  text   TEXT NOT NULL,
  PRIMARY KEY (surah, ayah)
);

-- ── FURUQ (semantic differentiation) ─────────────────────────────────
-- Comparison pairs (بحر × يمّ). `verified` gates what users ever see.
CREATE TABLE furuq (
  furuq_id     INTEGER PRIMARY KEY,
  root_a       TEXT NOT NULL,          -- "بحر"
  root_b       TEXT NOT NULL,          -- "يمّ"
  maqayis_a    TEXT, maqayis_b   TEXT, -- المعنى المحوري
  quran_a      TEXT, quran_b     TEXT, -- الدلالة القرآنية
  count_a      INTEGER, count_b  INTEGER,
  semitic_a    TEXT, semitic_b   TEXT, -- المقابل السامي (nullable)
  difference   TEXT NOT NULL,          -- الفرق (the payload)
  source       TEXT,                   -- "أبو هلال العسكري + جيفري"
  verified     INTEGER NOT NULL DEFAULT 0  -- 0 = hidden from users, 1 = live
);
CREATE INDEX idx_furuq_pair ON furuq(root_a, root_b);
CREATE INDEX idx_furuq_verified ON furuq(verified);

-- ── META ─────────────────────────────────────────────────────────────
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- INSERT INTO meta VALUES ('db_version','1.3'), ('built_at', ...);
