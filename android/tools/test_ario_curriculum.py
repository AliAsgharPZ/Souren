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
        self.assertEqual(len(curriculum["stages"]), (len(entries) + 4) // 5)
        self.assertGreater(len(curriculum["stages"]), 100)
        self.assertEqual(curriculum["stageSize"], 5)
        words = [word for stage in curriculum["stages"] for unit in stage["units"] for lesson in unit["lessons"] for section in lesson["sections"] if section["type"] == "learn" for word in section["entryIds"]]
        self.assertEqual(len(words), 552)
        self.assertEqual(len(set(words)), 552)
        for index, stage in enumerate(curriculum["stages"], 1):
            self.assertEqual(stage["level"], index)
            self.assertGreaterEqual(stage["difficultyMin"], 1)
            self.assertLessEqual(stage["difficultyMax"], 100)
            self.assertLessEqual(stage["difficultyMin"], stage["difficultyMax"])
            self.assertGreaterEqual(len(stage["units"][0]["lessons"][0]["sections"][2]["exercises"]), 3)

    def test_writing_curriculum_is_complete_and_linked(self):
        path = os.path.join(ROOT, "assets/db/ario_writing.json")
        with open(path, encoding="utf-8") as source:
            writing = json.load(source)
        courses = writing["courses"]
        self.assertEqual({course["id"] for course in courses}, {"spelling", "hekasre", "half-space", "literary-devices"})
        self.assertEqual(len(courses), 4)
        lesson_ids, exercise_ids = set(), set()
        lesson_count = 0
        for course in courses:
            self.assertTrue(course["units"])
            for unit in course["units"]:
                self.assertTrue(unit["lessons"])
                for lesson in unit["lessons"]:
                    lesson_count += 1
                    self.assertNotIn(lesson["id"], lesson_ids)
                    lesson_ids.add(lesson["id"])
                    sections = lesson["sections"]
                    self.assertEqual([section["type"] for section in sections], ["learn", "recall", "practice"])
                    self.assertTrue(sections[0]["content"])
                    for section in sections:
                        self.assertIsInstance(section["examples"], list)
                        self.assertTrue(all(isinstance(example, str) and example.strip() for example in section["examples"]))
                    self.assertTrue(sections[0]["examples"])
                    for section in sections[1:]:
                        self.assertGreaterEqual(len(section["exercises"]), 2)
                        for exercise in section["exercises"]:
                            self.assertNotIn(exercise["id"], exercise_ids)
                            exercise_ids.add(exercise["id"])
                            self.assertIn(exercise["answer"], exercise["options"])
                            self.assertGreaterEqual(len(set(exercise["options"])), 3)
                            self.assertTrue(exercise["explanation"])
        self.assertEqual(lesson_count, 18)
        self.assertEqual(len(exercise_ids), 72)

if __name__ == "__main__":
    unittest.main()
