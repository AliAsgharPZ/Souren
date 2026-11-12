import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "data"))
from ario_curriculum import level_dictionary, build_curriculum

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

class ArioCurriculumTest(unittest.TestCase):
    def test_all_dictionary_entries_are_levelled_and_staged_once(self):
        with open(os.path.join(ROOT, "assets/db/dataset.json"), encoding="utf-8") as source:
            dataset = json.load(source)
        with open(os.path.join(ROOT, "assets/db/categories.json"), encoding="utf-8") as source:
            categories = json.load(source)["cats"]
        entries = level_dictionary(dataset["entries"], categories)
        curriculum = build_curriculum(entries)
        self.assertEqual(len(entries), 552)
        self.assertEqual({entry["level"] for entry in entries}, set(range(1, 101)))
        self.assertEqual(len(curriculum["stages"]), 100)
        words = [word for stage in curriculum["stages"] for unit in stage["units"] for lesson in unit["lessons"] for section in lesson["sections"] if section["type"] == "learn" for word in section["entryIds"]]
        self.assertEqual(len(words), 552)
        self.assertEqual(len(set(words)), 552)
        for stage in curriculum["stages"]:
            self.assertGreaterEqual(len(stage["units"][0]["lessons"][0]["sections"][2]["exercises"]), 15)

if __name__ == "__main__":
    unittest.main()
