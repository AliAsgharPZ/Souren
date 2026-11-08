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
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


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


def run_codec(command: list[str], output: Path) -> None:
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)


def compress_candidates(db_path: Path, work: Path) -> list[dict]:
    candidates = []

    # XZ/LZMA2 extreme: high memory/time, generally excellent for text-heavy DBs.
    xz_path = work / "ganjoor.sqlite.xz"
    with db_path.open("rb") as src, lzma.open(
        xz_path, "wb", format=lzma.FORMAT_XZ,
        check=lzma.CHECK_CRC64, preset=9 | lzma.PRESET_EXTREME
    ) as dst:
        shutil.copyfileobj(src, dst, length=1024 * 1024)
    candidates.append({"codec": "xz-lzma2-9e", "path": xz_path, "bytes": xz_path.stat().st_size})

    gz_path = work / "ganjoor.sqlite.gz"
    with db_path.open("rb") as src, gzip.open(gz_path, "wb", compresslevel=9, mtime=0) as dst:
        shutil.copyfileobj(src, dst, length=1024 * 1024)
    candidates.append({"codec": "gzip-9", "path": gz_path, "bytes": gz_path.stat().st_size})

    bz_path = work / "ganjoor.sqlite.bz2"
    with db_path.open("rb") as src, bz2.open(bz_path, "wb", compresslevel=9) as dst:
        shutil.copyfileobj(src, dst, length=1024 * 1024)
    candidates.append({"codec": "bzip2-9", "path": bz_path, "bytes": bz_path.stat().st_size})

    zstd = shutil.which("zstd")
    if zstd:
        zst_path = work / "ganjoor.sqlite.zst"
        run_codec([zstd, "-q", "-22", "--ultra", "--long=27", "-T0", "-f",
                   str(db_path), "-o", str(zst_path)], zst_path)
        candidates.append({"codec": "zstd-22-ultra-long27", "path": zst_path,
                           "bytes": zst_path.stat().st_size})

    brotli = shutil.which("brotli")
    if brotli:
        br_path = work / "ganjoor.sqlite.br"
        run_codec([brotli, "-q", "11", "-f", str(db_path), "-o", str(br_path)], br_path)
        candidates.append({"codec": "brotli-11", "path": br_path,
                           "bytes": br_path.stat().st_size})

    return sorted(candidates, key=lambda x: x["bytes"])


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
    if sha256(restored.read_bytes()) != db_hash:
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
    db_path = output / "ganjoor-full.sqlite"
    if db_path.exists():
        db_path.unlink()

    counts = {"json_files": 0, "poets": 0, "categories": 0, "poems": 0}
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
            CREATE VIRTUAL TABLE poem_search USING fts5(
              title, poet, body, content='', tokenize='unicode61'
            );
            CREATE INDEX idx_categories_poet ON categories(poet_id);
            CREATE INDEX idx_poems_cat ON poems(cat_id);
            CREATE INDEX idx_poems_slug ON poems(poet_slug);
        """)

        poet_names = {}
        db.execute("BEGIN")
        for file in files:
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
                db.execute(
                    "INSERT INTO poem_search(rowid,title,poet,body) VALUES(?,?,?,?)",
                    (int(poem_id), compact_text(obj.get("Title")),
                     poet_names.get(slug, slug), poem_text(obj))
                )
                counts["poems"] += 1
        db.commit()
        db.execute("ANALYZE")
        db.execute("VACUUM")

        file_count = db.execute("SELECT COUNT(*) FROM source_files").fetchone()[0]
        poem_count = db.execute("SELECT COUNT(*) FROM poems").fetchone()[0]
        if file_count != counts["json_files"] or poem_count != counts["poems"]:
            raise RuntimeError("Row-count verification failed")
        check = db.execute("PRAGMA integrity_check").fetchone()[0]
        if check != "ok":
            raise RuntimeError(f"SQLite integrity check failed: {check}")
    finally:
        db.close()

    db_hash = sha256(db_path.read_bytes())
    with tempfile.TemporaryDirectory(prefix="souren-ganjoor-compress-") as temp:
        candidates = compress_candidates(db_path, Path(temp))
        winner = candidates[0]
        verify_archive(winner, db_hash, Path(temp))
        suffix = winner["path"].suffix
        final_archive = output / f"ganjoor-full.sqlite{suffix}"
        shutil.copy2(winner["path"], final_archive)

    report = {
        "format": 1,
        "source": "https://github.com/ganjoor/ganjoor-data",
        "source_files": counts["json_files"],
        "source_json_bytes": source_bytes,
        "poets": counts["poets"],
        "categories": counts["categories"],
        "poems": counts["poems"],
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
