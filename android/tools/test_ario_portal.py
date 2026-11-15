import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "android" / "lib" / "main.dart").read_text()


class ArioPortalNavigationTests(unittest.TestCase):
    def test_exact_five_tabs_and_page_order(self):
        self.assertIn(
            "? <Widget>[_arioHome(d), _arioActivities(d), _arioWorkshop(d), _arioProfile(d), _arioSettings()]",
            SOURCE,
        )
        expected = [
            "(Symbols.home_rounded, 'پیشگاه')",
            "(Symbols.event_note_rounded, 'فعالیت‌ها')",
            "(Symbols.science_rounded, 'کارگاه')",
            "(Symbols.person_rounded, 'نمایه')",
            "(Symbols.settings_rounded, 'پیکربندی')",
        ]
        start = SOURCE.index("Widget _navBar()")
        end = SOURCE.index("Widget navItem(int i)", start)
        nav = SOURCE[start:end].split(": <(IconData, String)>", 1)[0]
        positions = [nav.index(item) for item in expected]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(nav.count("(Symbols."), 5)

    def test_learning_is_a_route_not_a_tab(self):
        self.assertIn("_open(_arioLearning(d))", SOURCE)
        self.assertIn("_arioPageShell('مسیر یادگیری'", SOURCE)
        pages = SOURCE.split("final pages = arioMode", 1)[1].split(": <Widget>", 1)[0]
        self.assertNotIn("_arioLearning(d)", pages)

    def test_portal_keeps_continue_daily_mission_and_speed_header(self):
        start = SOURCE.index("Widget _arioHome(Dictionary d)")
        end = SOURCE.index("Widget _arioLearning(Dictionary d)", start)
        home = SOURCE[start:end]
        self.assertIn("ادامهٔ یادگیری", home)
        self.assertIn("مأموریت روزانه", home)
        self.assertIn("تمرین امروز", home)
        self.assertIn("headerAction: () => _open(ArioSpeedChallengePage(", home)

    def test_workshop_contains_independent_practice_and_review(self):
        start = SOURCE.index("Widget _arioWorkshop(Dictionary d)")
        end = SOURCE.index("Widget _arioPractice(Dictionary d)", start)
        workshop = SOURCE[start:end]
        self.assertIn("تمرین آزاد واژه‌ها", workshop)
        self.assertIn("مرور آموخته‌ها", workshop)

    def test_no_social_tab_or_social_feature_remains(self):
        for forbidden in ("_arioCommunity", "_arioTopic(", "Ghost Challenge", "اجتماع", "گروه‌های موضوعی", "ghostMode"):
            self.assertNotIn(forbidden, SOURCE)

    def test_gamification_and_ghost_challenge_are_local_only(self):
        model = (ROOT / "android" / "lib" / "data" / "ario_gamification.dart").read_text()
        start = SOURCE.index("enum ArioChallengeMode")
        end = SOURCE.index("class ArioLogo", start)
        challenge = SOURCE[start:end]
        self.assertIn("arioGame.toJson()", SOURCE)
        self.assertIn("_openArioGhostChallenge", SOURCE)
        self.assertIn("initialGhostTrack: arioGame.ghostBestTrack", SOURCE)
        self.assertIn("onGhostRunCompleted: _recordArioGhostRun", SOURCE)
        self.assertIn("چالش شبح", SOURCE)
        for forbidden in ("HttpClient", "AccountApi", "Uri.parse", "workers.dev", "http://", "https://"):
            self.assertNotIn(forbidden, model)
            self.assertNotIn(forbidden, challenge)

    def test_offline_missions_reports_events_topics_and_avatar_are_connected(self):
        self.assertIn("arioGame.dailyMissions(today)", SOURCE)
        self.assertIn("arioGame.weeklySummary()", SOURCE)
        self.assertIn("arioGame.monthlySummary()", SOURCE)
        self.assertIn("arioGame.offlineEvent()", SOURCE)
        self.assertIn("topicPractice: true", SOURCE)
        self.assertIn("_arioAvatarPicker()", SOURCE)
        self.assertIn("arioGame.setAvatar", SOURCE)


if __name__ == "__main__":
    unittest.main()
