#!/usr/bin/env python3
"""Lossless semantic packing of the complete official Ganjoor JSON export.

All JSON values and file paths are retained. Object keys are dictionary-coded
once and every source JSON document is encoded as a CBOR record, then XZ/LZMA2
compressed. The verification pass reconstructs every JSON object and compares
a canonical semantic SHA-256 over every path and payload.
"""
from __future__ import annotations
import argparse, hashlib, json, lzma, shutil, subprocess, tempfile
from pathlib import Path
import cbor2

def walk_keys(value, keys):
    if isinstance(value, dict):
        for k, v in value.items():
            keys.add(k)
            walk_keys(v, keys)
    elif isinstance(value, list):
        for v in value:
            walk_keys(v, keys)

def remap(value, key_to_id):
    if isinstance(value, dict):
        return {key_to_id[k]: remap(v, key_to_id) for k, v in value.items()}
    if isinstance(value, list):
        return [remap(v, key_to_id) for v in value]
    return value

def unmap(value, id_to_key):
    if isinstance(value, dict):
        return {id_to_key[k]: unmap(v, id_to_key) for k, v in value.items()}
    if isinstance(value, list):
        return [unmap(v, id_to_key) for v in value]
    return value

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")

def add_digest(digest, path, value):
    digest.update(path.encode("utf-8"))
    digest.update(b"\0")
    digest.update(canonical(value))
    digest.update(b"\0")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--out", type=Path, default=Path("dist/ganjoor"))
    args = ap.parse_args()
    files = sorted(p for p in args.source.rglob("*.json") if p.is_file())
    if not files:
        raise SystemExit("No JSON source files found")
    args.out.mkdir(parents=True, exist_ok=True)

    # Pass 1: collect the complete set of object keys.
    keys = set()
    source_bytes = 0
    for i, path in enumerate(files, 1):
        raw = path.read_bytes()
        source_bytes += len(raw)
        walk_keys(json.loads(raw), keys)
        if i % 10000 == 0:
            print(f"[keys] scanned {i:,}/{len(files):,}", flush=True)
    key_list = sorted(keys)
    key_to_id = {k: i for i, k in enumerate(key_list)}
    id_to_key = {i: k for i, k in enumerate(key_list)}
    packed = args.out / "ganjoor-full.cbor"
    source_digest = hashlib.sha256()

    # Pass 2: encode every file as one self-describing CBOR record.
    with packed.open("wb") as out:
        cbor2.dump({"format": 2, "file_count": len(files), "keys": key_list}, out)
        for i, path in enumerate(files, 1):
            rel = path.relative_to(args.source).as_posix()
            obj = json.loads(path.read_bytes())
            add_digest(source_digest, rel, obj)
            cbor2.dump([rel, remap(obj, key_to_id)], out)
            if i % 10000 == 0:
                print(f"[pack] encoded {i:,}/{len(files):,}", flush=True)

    # XZ is streamed, so the uncompressed CBOR need not be held in memory.
    archive = args.out / "ganjoor-full.cbor.xz"
    xz = shutil.which("xz")
    if not xz:
        raise SystemExit("xz executable is unavailable")
    with archive.open("wb") as dest:
        subprocess.run([xz, "-T0", "-9e", "--check=crc64", "-c", str(packed)],
                       check=True, stdout=dest)
    packed.unlink()

    # Decode the archive and verify every file path and every JSON value.
    restored_digest = hashlib.sha256()
    with lzma.open(archive, "rb") as src:
        decoder = cbor2.CBORDecoder(src)
        header = decoder.decode()
        if header.get("format") != 2 or header.get("file_count") != len(files):
            raise SystemExit("CBOR header verification failed")
        decoded_keys = header["keys"]
        decoded_map = {i: k for i, k in enumerate(decoded_keys)}
        for i in range(len(files)):
            rel, encoded = decoder.decode()
            obj = unmap(encoded, decoded_map)
            add_digest(restored_digest, rel, obj)
            if (i + 1) % 10000 == 0:
                print(f"[verify] restored {i+1:,}/{len(files):,}", flush=True)
    if source_digest.hexdigest() != restored_digest.hexdigest():
        raise SystemExit("Lossless semantic round-trip verification FAILED")

    report = {
        "format": 2,
        "source": "https://github.com/ganjoor/ganjoor-data",
        "source_files": len(files),
        "source_json_bytes": source_bytes,
        "dictionary_keys": len(key_list),
        "archive": archive.name,
        "archive_bytes": archive.stat().st_size,
        "source_semantic_sha256": source_digest.hexdigest(),
        "lossless_semantic_round_trip_verified": True,
        "all_source_files_and_json_values_preserved": True,
        "target_under_50_mb": archive.stat().st_size < 50_000_000
    }
    (args.out / "compact-compression-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)

if __name__ == "__main__":
    main()
