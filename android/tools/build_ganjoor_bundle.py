#!/usr/bin/env python3
"""Build a lossless, compact, offline Ganjoor corpus for Souren.

Every *.json file under the upstream export is copied byte-for-byte into
SQLite source_files. Nothing is filtered, normalized, rewritten, or omitted.
Separate relational/FTS tables are derived indexes only; source_files remains
the canonical lossless archive.

The database is then benchmark-compressed with every available high-ratio
codec. The smallest verified result is emitted.
"""
from __future__ import annotations

import argparse
import bz2
import gzip
import hashlib
import json
import lzma
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def compact_text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    return str(value)


def poem_text(obj: dict) -> str:
    parts = []
    for section in obj.get("Sections") or []:
        if isinstance(section, dict):
            parts.append(compact_text(section.get("PlainText")))
    for verse in obj.get("Verses") or []:
        if isinstance(verse, dict):
            parts.append(compact_text(verse.get("Text")))
            parts.append(compact_text(verse.get("CoupletSummary")))
    parts.append(compact_text(obj.get("PoemSummary")))
    return "\n".join(x for x in parts if x)


def run_codec(command: list[str], output: Path, timeout_seconds: int) -> bool:
    print('[compress] start: ' + ' '.join(command), flush=True)
    try:
        with output.open('wb') as destination:
            subprocess.run(command, check=True, stdout=destination, stderr=subprocess.DEVNULL, timeout=timeout_seconds)
        print(f'[compress] done: {output.name} ({output.stat().st_size:,} bytes)', flush=True)
        return True
    except subprocess.TimeoutExpired:
        output.unlink(missing_ok=True)
        print(f'[compress] timeout after {timeout_seconds // 60} min; skipping this codec', flush=True)
        return False


def compress_candidates(db_path: Path, work: Path) -> list[dict]:
    candidates = []
    # Strong codecs, but each has a time limit so no single one can stall the build.
    xz_path = work / 'ganjoor.sqlite.xz'
    xz = shutil.which('xz')
    if xz and run_codec([xz, '-T0', '-9e', '--check=crc64', '-c', str(db_path)], xz_path, 45 * 60):
        candidates.append({'codec': 'xz-lzma2-9e', 'path': xz_path, 'bytes': xz_path.stat().st_size})
    zstd = shutil.which('zstd')
    if zstd:
        zst_path = work / 'ganjoor.sqlite.zst'
        # Avoid --long=27: very high RAM use for marginal/uncertain gains.
        if run_codec([zstd, '-q', '-22', '--ultra', '-T0', '-f', str(db_path), '-o', str(zst_path)], zst_path, 20 * 60):
            candidates.append({'codec': 'zstd-22-ultra', 'path': zst_path, 'bytes': zst_path.stat().st_size})
    brotli = shutil.which('brotli')
    if brotli:
        br_path = work / 'ganjoor.sqlite.br'
        if run_codec([brotli, '-q', '11', '-f', str(db_path), '-o', str(br_path)], br_path, 20 * 60):
            candidates.append({'codec': 'brotli-11', 'path': br_path, 'bytes': br_path.stat().st_size})
    bz_path = work / 'ganjoor.sqlite.bz2'
    if run_codec(['bzip2', '-9', '-c', str(db_path)], bz_path, 10 * 60):
        candidates.append({'codec': 'bzip2-9', 'path': bz_path, 'bytes': bz_path.stat().st_size})
    gz_path = work / 'ganjoor.sqlite.gz'
    if run_codec(['gzip', '-9', '-c', str(db_path)], gz_path, 5 * 60):
        candidates.append({'codec': 'gzip-9', 'path': gz_path, 'bytes': gz_path.stat().st_size})
    if not candidates:
        raise RuntimeError('Every compression codec failed or timed out')
    return sorted(candidates, key=lambda x: x['bytes'])

def verify_archive(candidate: dict, db_hash: str, work: Path) -> None:
    restored = work / "restored.sqlite"
    codec = candidate["codec"]
    if codec.startswith("xz-"):
        with lzma.open(candidate["path"], "rb") as src, restored.open("wb") as dst:
            shutil.copyfileobj(src, dst, length=1024 * 1024)
    elif codec.startswith("gzip-"):
        with gzip.open(candidate["path"], "rb") as src, restored.open("wb") as dst:
            shutil.copyfileobj(src, dst, length=1024 * 1024)
    elif codec.startswith("bzip2-"):
        with bz2.open(candidate["path"], "rb") as src, restored.open("wb") as dst:
            shutil.copyfileobj(src, dst, length=1024 * 1024)
    elif codec.startswith("zstd-"):
        subprocess.run([shutil.which("zstd"), "-q", "-d", "-f",
                        str(candidate["path"]), "-o", str(restored)], check=True)
    elif codec.startswith("brotli-"):
        subprocess.run([shutil.which("brotli"), "-d", "-f",
                        str(candidate["path"]), "-o", str(restored)], check=True)
    else:
        raise RuntimeError(f"Unknown codec: {codec}")
    if sha256_file(restored) != db_hash:
        raise RuntimeError(f"Lossless round-trip failed for {codec}")
    with sqlite3.connect(restored) as db:
        result = db.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise RuntimeError(f"Restored SQLite integrity failed: {result}")
    restored.unlink()


def build(source: Path, output: Path) -> dict:
    files = sorted(p for p in source.rglob("*.json") if p.is_file())
    if not files:
        raise RuntimeError(f"No JSON source files found under {source}")

    output.mkdir(parents=True, exist_ok=True)
    db_path = output / "souren-content.sqlite"
    if db_path.exists():
        db_path.unlink()

    counts = {
        "json_files": 0, "poets": 0, "categories": 0, "poems": 0,
        "dictionary_entries": 0, "dictionary_meanings": 0, "proverbs": 0,
        "content_relations": 0,
    }
    source_bytes = 0

    db = sqlite3.connect(db_path)
    try:
        db.execute("PRAGMA page_size=4096")
        db.execute("PRAGMA journal_mode=OFF")
        db.execute("PRAGMA synchronous=OFF")
        db.execute("PRAGMA temp_store=MEMORY")
        db.execute("PRAGMA locking_mode=EXCLUSIVE")
        db.executescript("""
            CREATE TABLE source_files(
              path TEXT PRIMARY KEY,
              raw_json BLOB NOT NULL,
              sha256 TEXT NOT NULL,
              byte_length INTEGER NOT NULL
            ) WITHOUT ROWID;
            CREATE TABLE poets(
              id INTEGER PRIMARY KEY, slug TEXT NOT NULL, name TEXT,
              nickname TEXT, full_url TEXT, source_path TEXT NOT NULL
            );
            CREATE TABLE categories(
              id INTEGER PRIMARY KEY, poet_id INTEGER, title TEXT,
              full_url TEXT, book_name TEXT, source_path TEXT NOT NULL
            );
            CREATE TABLE poems(
              id INTEGER PRIMARY KEY, cat_id INTEGER, title TEXT,
              full_title TEXT, full_url TEXT, poet_slug TEXT NOT NULL,
              source_path TEXT NOT NULL
            );
            CREATE TABLE dictionary_entries(
              id INTEGER PRIMARY KEY, headword TEXT NOT NULL UNIQUE,
              source_path TEXT NOT NULL
            );
            CREATE TABLE dictionary_meanings(
              entry_id INTEGER NOT NULL, ordinal INTEGER NOT NULL,
              meaning TEXT NOT NULL, PRIMARY KEY(entry_id, ordinal)
            );
            CREATE TABLE dictionary_categories(
              category_key TEXT PRIMARY KEY, title TEXT NOT NULL
            );
            CREATE TABLE dictionary_category_entries(
              category_key TEXT NOT NULL, entry_id INTEGER NOT NULL,
              PRIMARY KEY(category_key, entry_id)
            );
            CREATE TABLE proverbs(
              id TEXT PRIMARY KEY, title TEXT NOT NULL, meaning TEXT NOT NULL
            );
            CREATE TABLE content_relations(
              source_type TEXT NOT NULL, source_id TEXT NOT NULL,
              relation TEXT NOT NULL, target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              PRIMARY KEY(source_type, source_id, relation, target_type, target_id)
            ) WITHOUT ROWID;
            CREATE VIRTUAL TABLE poem_search USING fts5(
              title, poet, body, content='', tokenize='unicode61'
            );
            CREATE VIRTUAL TABLE dictionary_search USING fts5(
              headword, meanings, content='', tokenize='unicode61'
            );
            CREATE INDEX idx_categories_poet ON categories(poet_id);
            CREATE INDEX idx_poems_cat ON poems(cat_id);
            CREATE INDEX idx_poems_slug ON poems(poet_slug);
            CREATE INDEX idx_dictionary_meanings_entry ON dictionary_meanings(entry_id);
            CREATE INDEX idx_dictionary_category_entries_entry ON dictionary_category_entries(entry_id);
            CREATE INDEX idx_relations_target ON content_relations(target_type, target_id);
            CREATE VIEW poem_catalog AS
              SELECT p.id, p.cat_id, p.title, p.full_title, p.full_url,
                     p.poet_slug, po.name AS poet_name, c.title AS category_title,
                     p.source_path
              FROM poems p
              LEFT JOIN poets po ON po.slug = p.poet_slug
              LEFT JOIN categories c ON c.id = p.cat_id;
            CREATE VIEW dictionary_catalog AS
              SELECT e.id, e.headword,
                     group_concat(m.meaning, ' | ') AS meanings,
                     e.source_path
              FROM dictionary_entries e
              LEFT JOIN dictionary_meanings m ON m.entry_id = e.id
              GROUP BY e.id, e.headword, e.source_path;
        """)

        poet_names = {}
        poet_ids = {}
        db.execute("BEGIN")
        for index, file in enumerate(files, 1):
            if index == 1 or index % 5000 == 0:
                print(f'[build] imported {index:,}/{len(files):,} JSON files', flush=True)
            rel = file.relative_to(source).as_posix()
            raw = file.read_bytes()
            # Parse every JSON file before insertion: corrupt source must fail the build.
            obj = json.loads(raw)
            digest = sha256(raw)
            db.execute(
                "INSERT INTO source_files(path,raw_json,sha256,byte_length) VALUES(?,?,?,?)",
                (rel, sqlite3.Binary(raw), digest, len(raw))
            )
            counts["json_files"] += 1
            source_bytes += len(raw)

            if not isinstance(obj, dict):
                continue

            if rel.startswith("poets/") and rel.endswith("/poet.json"):
                slug = rel.split("/")[1]
                poet_names[slug] = compact_text(obj.get("Name") or obj.get("Nickname"))
                poet_ids[slug] = obj.get("Id")
                db.execute(
                    "INSERT OR REPLACE INTO poets VALUES(?,?,?,?,?,?)",
                    (obj.get("Id"), slug, obj.get("Name"), obj.get("Nickname"),
                     obj.get("FullUrl"), rel)
                )
                counts["poets"] += 1
            elif rel.startswith("poets/") and rel.endswith("/_cat.json"):
                db.execute(
                    "INSERT OR REPLACE INTO categories VALUES(?,?,?,?,?,?)",
                    (obj.get("Id"), obj.get("PoetId"), obj.get("Title"),
                     obj.get("FullUrl"), obj.get("BookName"), rel)
                )
                counts["categories"] += 1
            elif rel.startswith("poets/") and rel.endswith(".json") and (
                "Verses" in obj or "Sections" in obj
            ):
                slug = rel.split("/")[1]
                poem_id = obj.get("Id")
                db.execute(
                    "INSERT OR REPLACE INTO poems VALUES(?,?,?,?,?,?,?)",
                    (poem_id, obj.get("CatId"), obj.get("Title"),
                     obj.get("FullTitle"), obj.get("FullUrl"), slug, rel)
                )
                if poet_ids.get(slug) is not None:
                    db.execute(
                        "INSERT OR IGNORE INTO content_relations VALUES(?,?,?,?,?)",
                        ("poem", str(poem_id), "by_poet", "poet", str(poet_ids[slug]))
                    )
                if obj.get("CatId") is not None:
                    db.execute(
                        "INSERT OR IGNORE INTO content_relations VALUES(?,?,?,?,?)",
                        ("poem", str(poem_id), "in_category", "category", str(obj.get("CatId")))
                    )
                db.execute(
                    "INSERT INTO poem_search(rowid,title,poet,body) VALUES(?,?,?,?)",
                    (int(poem_id), compact_text(obj.get("Title")),
                     poet_names.get(slug, slug), poem_text(obj))
                )
                counts["poems"] += 1
        # Import Souren's own word/category/proverb data into this same DB.
        # The original JSON bytes are retained in source_files for lossless recovery.
        local_data = Path(__file__).resolve().parents[1] / "assets" / "db"
        local_paths = {
            "dictionary": local_data / "dataset.json",
            "categories": local_data / "categories.json",
            "proverbs": local_data / "proverbs.json",
        }
        local_objects = {}
        for kind, local_path in local_paths.items():
            if not local_path.is_file():
                raise RuntimeError(f"Required Souren data file is missing: {local_path}")
            raw = local_path.read_bytes()
            obj = json.loads(raw)
            rel = f"souren/assets/db/{local_path.name}"
            db.execute(
                "INSERT INTO source_files(path,raw_json,sha256,byte_length) VALUES(?,?,?,?)",
                (rel, sqlite3.Binary(raw), sha256(raw), len(raw))
            )
            counts["json_files"] += 1
            source_bytes += len(raw)
            local_objects[kind] = obj

        dictionary_obj = local_objects["dictionary"]
        meaning_index = {}
        for row in dictionary_obj.get("entries", []):
            if not isinstance(row, dict):
                continue
            headword = compact_text(row.get("ar")).strip()
            if not headword:
                continue
            cursor = db.execute(
                "INSERT OR IGNORE INTO dictionary_entries(headword,source_path) VALUES(?,?)",
                (headword, "souren/assets/db/dataset.json")
            )
            found = db.execute(
                "SELECT id FROM dictionary_entries WHERE headword=?", (headword,)
            ).fetchone()
            if not found:
                continue
            entry_id = found[0]
            meanings = [compact_text(x).strip() for x in (row.get("fa") or [])]
            meanings = [x for x in meanings if x]
            for ordinal, meaning in enumerate(meanings):
                db.execute(
                    "INSERT OR IGNORE INTO dictionary_meanings(entry_id,ordinal,meaning) VALUES(?,?,?)",
                    (entry_id, ordinal, meaning)
                )
                for token in re.findall(r"[\u0600-\u06FF]+", meaning):
                    if len(token) >= 3:
                        meaning_index.setdefault(token, set()).add(entry_id)
            db.execute(
                "INSERT INTO dictionary_search(rowid,headword,meanings) VALUES(?,?,?)",
                (entry_id, headword, " ".join(meanings))
            )
            counts["dictionary_entries"] += 1
            counts["dictionary_meanings"] += len(meanings)

        cats_obj = local_objects["categories"]
        for category_key, words in (cats_obj.get("cats") or {}).items():
            db.execute(
                "INSERT OR REPLACE INTO dictionary_categories(category_key,title) VALUES(?,?)",
                (str(category_key), str(category_key))
            )
            for word in words or []:
                match = db.execute(
                    "SELECT id FROM dictionary_entries WHERE headword=?", (str(word),)
                ).fetchone()
                if match:
                    db.execute(
                        "INSERT OR IGNORE INTO dictionary_category_entries VALUES(?,?)",
                        (str(category_key), match[0])
                    )
                    db.execute(
                        "INSERT OR IGNORE INTO content_relations VALUES(?,?,?,?,?)",
                        ("word", str(match[0]), "in_category", "dictionary_category", str(category_key))
                    )

        for proverb in (local_objects["proverbs"].get("proverbs") or []):
            if not isinstance(proverb, dict):
                continue
            proverb_id = compact_text(proverb.get("id")).strip()
            title = compact_text(proverb.get("title")).strip()
            meaning = compact_text(proverb.get("meaning")).strip()
            if not proverb_id or not title or not meaning:
                continue
            db.execute(
                "INSERT OR REPLACE INTO proverbs(id,title,meaning) VALUES(?,?,?)",
                (proverb_id, title, meaning)
            )
            counts["proverbs"] += 1
            for token in set(re.findall(r"[\u0600-\u06FF]+", title + " " + meaning)):
                if len(token) < 3:
                    continue
                for entry_id in meaning_index.get(token, ()):
                    db.execute(
                        "INSERT OR IGNORE INTO content_relations VALUES(?,?,?,?,?)",
                        ("proverb", proverb_id, "mentions_word", "word", str(entry_id))
                    )

        # Categories and poems point to the same poet records; this relation
        # table gives the app one stable join surface for cross-content links.
        for row in db.execute("SELECT id, poet_id FROM categories WHERE poet_id IS NOT NULL"):
            db.execute(
                "INSERT OR IGNORE INTO content_relations VALUES(?,?,?,?,?)",
                ("category", str(row[0]), "belongs_to", "poet", str(row[1]))
            )

        # Complete cross-links after all source rows have been imported, so
        # path ordering can never leave poems disconnected from their poet.
        db.execute("""
            INSERT OR IGNORE INTO content_relations
            SELECT 'poem', CAST(p.id AS TEXT), 'by_poet', 'poet', CAST(po.id AS TEXT)
            FROM poems p JOIN poets po ON po.slug = p.poet_slug
        """)
        db.execute("""
            INSERT OR IGNORE INTO content_relations
            SELECT 'poem', CAST(id AS TEXT), 'in_category', 'category', CAST(cat_id AS TEXT)
            FROM poems WHERE cat_id IS NOT NULL
        """)
        for slug, name in poet_names.items():
            db.execute(
                "UPDATE poem_search SET poet=? WHERE rowid IN (SELECT id FROM poems WHERE poet_slug=?)",
                (name, slug)
            )

        # Verify every retained source payload against the digest recorded at import.
        verified_sources = 0
        for raw, digest, byte_length in db.execute(
            "SELECT raw_json, sha256, byte_length FROM source_files"
        ):
            if len(raw) != byte_length or sha256(raw) != digest:
                raise RuntimeError("A source JSON payload failed its byte-level SHA-256 check")
            verified_sources += 1
        if verified_sources != counts["json_files"]:
            raise RuntimeError("Source payload verification count mismatch")

        counts["content_relations"] = db.execute(
            "SELECT COUNT(*) FROM content_relations"
        ).fetchone()[0]
        db.commit()
        db.execute("ANALYZE")
        db.execute("VACUUM")

        file_count = db.execute("SELECT COUNT(*) FROM source_files").fetchone()[0]
        poem_count = db.execute("SELECT COUNT(*) FROM poems").fetchone()[0]
        dictionary_count = db.execute("SELECT COUNT(*) FROM dictionary_entries").fetchone()[0]
        proverb_count = db.execute("SELECT COUNT(*) FROM proverbs").fetchone()[0]
        if (file_count != counts["json_files"] or poem_count != counts["poems"]
                or dictionary_count != counts["dictionary_entries"]
                or proverb_count != counts["proverbs"]):
            raise RuntimeError("Unified database row-count verification failed")
        check = db.execute("PRAGMA integrity_check").fetchone()[0]
        if check != "ok":
            raise RuntimeError(f"SQLite integrity check failed: {check}")
    finally:
        db.close()

    db_hash = sha256_file(db_path)
    with tempfile.TemporaryDirectory(prefix="souren-ganjoor-compress-") as temp:
        candidates = compress_candidates(db_path, Path(temp))
        print('[build] codec sizes: ' + ', '.join(c['codec'] + '=' + str(c['bytes']) for c in candidates), flush=True)
        winner = candidates[0]
        verify_archive(winner, db_hash, Path(temp))
        suffix = winner["path"].suffix
        final_archive = output / f"souren-content.sqlite{suffix}"
        shutil.copy2(winner["path"], final_archive)

    report = {
        "format": 1,
        "source": "https://github.com/ganjoor/ganjoor-data",
        "source_files": counts["json_files"],
        "source_json_bytes": source_bytes,
        "poets": counts["poets"],
        "categories": counts["categories"],
        "poems": counts["poems"],
        "dictionary_entries": counts["dictionary_entries"],
        "dictionary_meanings": counts["dictionary_meanings"],
        "proverbs": counts["proverbs"],
        "content_relations": counts["content_relations"],
        "sqlite_bytes": db_path.stat().st_size,
        "sqlite_sha256": db_hash,
        "compression_candidates": [
            {"codec": c["codec"], "bytes": c["bytes"],
             "ratio_percent_of_sqlite": round(100 * c["bytes"] / db_path.stat().st_size, 2)}
            for c in candidates
        ],
        "selected_codec": winner["codec"],
        "selected_archive": final_archive.name,
        "selected_bytes": final_archive.stat().st_size,
        "lossless_round_trip_verified": True,
        "source_payloads_preserved_byte_for_byte": True,
        "source_payloads_sha256_verified": True,
        "database_scope": ["ganjoor", "dictionary", "dictionary_categories", "proverbs"],
    }
    (output / "compression-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True,
                        help="Path to a complete local clone of ganjoor/ganjoor-data")
    parser.add_argument("--out", type=Path, default=Path("dist/ganjoor"))
    args = parser.parse_args()
    build(args.source.resolve(), args.out.resolve())


if __name__ == "__main__":
    main()
