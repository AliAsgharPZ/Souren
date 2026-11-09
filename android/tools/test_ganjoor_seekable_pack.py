import json
import shutil
import tempfile
import unittest
from pathlib import Path

from build_ganjoor_seekable_pack import build


@unittest.skipUnless(shutil.which("zstd"), "zstd CLI is required")
class SeekablePackTests(unittest.TestCase):
    def test_indexed_files_round_trip_in_independent_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            output = root / "output"
            (source / "poets" / "test-poet").mkdir(parents=True)
            (source / "manifest.json").write_text(
                json.dumps({"Poets": [{"Name": "آزمایشی"}]}), encoding="utf-8"
            )
            (source / "poets" / "test-poet" / "poet.json").write_text(
                json.dumps({"Id": 1, "Name": "آزمایشی"}), encoding="utf-8"
            )
            (source / "poets" / "test-poet" / "_cat.json").write_text(
                json.dumps({"Id": 2, "PoetId": 1, "Title": "دیوان", "FullUrl": "test-poet/cat"}),
                encoding="utf-8",
            )
            poem = {"Id": 3, "Title": "شعر آزمایشی", "Verses": [{"Text": "بیت اول"}]}
            (source / "poets" / "test-poet" / "3.json").write_text(
                json.dumps(poem, ensure_ascii=False), encoding="utf-8"
            )

            report = build(source, output, chunk_mib=8, max_total_mib=20)
            self.assertTrue(report["all_frames_round_trip_verified"])
            self.assertTrue(report["all_source_ranges_sha256_verified"])

            index = json.loads((output / "souren-ganjoor-index.json").read_text("utf-8"))
            self.assertIn("poets/test-poet/3.json", index["files"])
            self.assertIn("catalog/books.json", index["files"])
            self.assertEqual(index["format"], 1)


if __name__ == "__main__":
    unittest.main()
