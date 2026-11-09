#!/usr/bin/env python3
"""Build a seekable, independently-compressed Ganjoor content pack for Souren.

The pack is a concatenation of independent Zstandard frames. The sidecar index
maps every source JSON file to its frame and byte range. The app downloads the
pack once, then decompresses only the frame containing the requested file.
No extracted corpus is persisted on the device.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
                    encoding="utf-8")


def build(source: Path, output: Path, chunk_mib: int, max_total_mib: int) -> dict:
    zstd = shutil.which("zstd")
    if not zstd:
        raise RuntimeError("zstd executable is required")
    if chunk_mib < 8 or chunk_mib > 256:
        raise ValueError("--chunk-mib must be between 8 and 256")

    files = sorted(p for p in source.rglob("*.json") if p.is_file())
    if not files or not (source / "manifest.json").is_file():
        raise RuntimeError("The complete Ganjoor export and manifest.json are required")

    books = []
    for path in files:
        rel = path.relative_to(source).as_posix()
        if rel.startswith("poets/") and rel.endswith("/_cat.json"):
            obj = json.loads(path.read_bytes())
            books.append({
                "Id": obj.get("Id"),
                "PoetId": obj.get("PoetId"),
                "Title": obj.get("Title"),
                "FullUrl": obj.get("FullUrl"),
                "BookName": obj.get("BookName"),
            })
    books.sort(key=lambda row: (str(row.get("PoetId") or ""), str(row.get("Title") or "")))
    synthetic = json.dumps({"Books": books}, ensure_ascii=False,
                           separators=(",", ":")).encode("utf-8")

    output.mkdir(parents=True, exist_ok=True)
    pack_path = output / "souren-ganjoor-pack.bin"
    index_path = output / "souren-ganjoor-index.json"
    pack_path.unlink(missing_ok=True)

    max_chunk_bytes = chunk_mib * 1024 * 1024
    long_bits = math.ceil(math.log2(max_chunk_bytes))
    index_files: dict[str, dict] = {}
    chunks: list[dict] = []
    source_bytes = 0

    with tempfile.TemporaryDirectory(prefix="souren-pack-") as tmp:
        tmpdir = Path(tmp)
        raw_path = tmpdir / "chunk.raw"
        raw_stream = raw_path.open("wb")
        raw_size = 0
        chunk_number = 0

        def flush_chunk() -> None:
            nonlocal raw_stream, raw_size, chunk_number
            if raw_size == 0:
                return
            raw_stream.flush()
            raw_stream.close()
            compressed_offset = pack_path.stat().st_size if pack_path.exists() else 0
            command = [zstd, "-q", "-22", "--ultra", f"--long={long_bits}",
                       "-T0", "-c", str(raw_path)]
            with pack_path.open("ab") as destination:
                subprocess.run(command, check=True, stdout=destination)
            compressed_length = pack_path.stat().st_size - compressed_offset
            chunks.append({
                "id": chunk_number,
                "compressed_offset": compressed_offset,
                "compressed_length": compressed_length,
                "raw_length": raw_size,
                "sha256": hashlib.sha256(raw_path.read_bytes()).hexdigest(),
            })
            chunk_number += 1
            raw_size = 0
            raw_stream = raw_path.open("wb")

        def add_file(path: str, data: bytes) -> None:
            nonlocal raw_size, source_bytes
            if len(data) > max_chunk_bytes:
                raise RuntimeError(
                    f"{path} is {len(data):,} bytes, larger than the "
                    f"{max_chunk_bytes:,}-byte frame limit"
                )
            if raw_size and raw_size + len(data) > max_chunk_bytes:
                flush_chunk()
            offset = raw_size
            raw_stream.write(data)
            raw_size += len(data)
            source_bytes += len(data)
            index_files[path] = {
                "chunk": chunk_number,
                "offset": offset,
                "length": len(data),
                "sha256": sha256(data),
            }

        for number, path in enumerate(files, 1):
            rel = path.relative_to(source).as_posix()
            add_file(rel, path.read_bytes())
            if number % 10000 == 0:
                print(f"[pack] indexed {number:,}/{len(files):,} files", flush=True)

        add_file("catalog/books.json", synthetic)
        flush_chunk()
        raw_stream.close()

    pack_bytes = pack_path.stat().st_size
    index = {
        "format": 1,
        "source": "https://github.com/ganjoor/ganjoor-data",
        "source_revision": os.environ.get("GANJOOR_SOURCE_SHA", "main"),
        "chunk_mib": chunk_mib,
        "pack_bytes": pack_bytes,
        "source_files": len(files),
        "source_bytes": source_bytes,
        "chunks": chunks,
        "files": index_files,
    }
    write_json(index_path, index)
    index_bytes = index_path.stat().st_size
    total_bytes = pack_bytes + index_bytes
    if total_bytes > max_total_mib * 1024 * 1024:
        raise RuntimeError(
            f"Stored pack exceeds limit: {total_bytes:,} bytes "
            f"(pack={pack_bytes:,}, index={index_bytes:,}; "
            f"limit={max_total_mib * 1024 * 1024:,})"
        )

    # Validate every independent frame and every indexed source range.
    with tempfile.TemporaryDirectory(prefix="souren-pack-verify-") as verify_tmp:
        restored = Path(verify_tmp) / "restored.raw"
        with pack_path.open("rb") as pack:
            for chunk in chunks:
                pack.seek(chunk["compressed_offset"])
                compressed = pack.read(chunk["compressed_length"])
                frame = Path(verify_tmp) / f"frame-{chunk['id']}.zst"
                frame.write_bytes(compressed)
                with restored.open("wb") as destination:
                    subprocess.run([zstd, "-q", "-d", "-c", str(frame)],
                                   check=True, stdout=destination)
                raw = restored.read_bytes()
                if len(raw) != chunk["raw_length"] or sha256(raw) != chunk["sha256"]:
                    raise RuntimeError(f"Frame {chunk['id']} failed round-trip validation")
                for name, record in index_files.items():
                    if record["chunk"] != chunk["id"]:
                        continue
                    item = raw[record["offset"]:record["offset"] + record["length"]]
                    if len(item) != record["length"] or sha256(item) != record["sha256"]:
                        raise RuntimeError(f"Indexed source payload failed: {name}")
                frame.unlink()

    report = {
        "format": 1,
        "chunk_mib": chunk_mib,
        "source_files": len(files),
        "source_bytes": source_bytes,
        "chunks": len(chunks),
        "pack_bytes": pack_bytes,
        "index_bytes": index_bytes,
        "stored_bytes": total_bytes,
        "stored_mib": round(total_bytes / (1024 * 1024), 2),
        "max_stored_mib": max_total_mib,
        "all_frames_round_trip_verified": True,
        "all_source_ranges_sha256_verified": True,
    }
    write_json(output / "pack-report.json", report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("dist/ganjoor-pack"))
    parser.add_argument("--chunk-mib", type=int, default=64)
    parser.add_argument("--max-total-mib", type=int, default=200)
    args = parser.parse_args()
    build(args.source.resolve(), args.out.resolve(), args.chunk_mib,
          args.max_total_mib)


if __name__ == "__main__":
    main()
