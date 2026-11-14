import pathlib
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android" / "android" / "app" / "src" / "main"
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"

class ArioBrandingTests(unittest.TestCase):
    def test_exact_user_supplied_svg_is_preserved(self):
        svg = (ROOT / "android/assets/branding/ario-app-icon.svg").read_text()
        self.assertIn('viewBox="0 0 1024 1024"', svg)
        self.assertIn('fill: #f7f1e3', svg)
        self.assertIn('fill: #6f6657', svg)
        self.assertIn('M0,0v1024h1024V0H0ZM315.8,601.32v-108.33c157.98,0,276.51-38.23,348.12-70.3l44.28,98.85c-81.25,36.4-215.28,79.78-392.4,79.78Z', svg)

    def test_adaptive_icon_uses_exact_palette_and_vector_mark(self):
        adaptive = ET.parse(ANDROID / "res/mipmap-anydpi-v26/ario_launcher.xml").getroot()
        self.assertEqual(adaptive.tag, "adaptive-icon")
        self.assertEqual(adaptive.find("background").attrib[ANDROID_NS + "drawable"], "@color/ario_launcher_background")
        self.assertEqual(adaptive.find("foreground").attrib[ANDROID_NS + "drawable"], "@drawable/ario_launcher_foreground")
        color = ET.parse(ANDROID / "res/values/ario_launcher_background.xml").getroot()
        self.assertEqual(color.find("color").text, "#6F6657")
        foreground = ET.parse(ANDROID / "res/drawable/ario_launcher_foreground.xml").getroot()
        self.assertEqual(foreground.find("path").attrib[ANDROID_NS + "fillColor"], "#F7F1E3")

    def test_ario_activity_and_launcher_alias_have_distinct_identity(self):
        manifest = ET.parse(ANDROID / "AndroidManifest.xml").getroot()
        app = manifest.find("application")
        activity = next(x for x in app.findall("activity") if x.attrib.get(ANDROID_NS + "name") == ".ArioActivity")
        alias = next(x for x in app.findall("activity-alias") if x.attrib.get(ANDROID_NS + "name") == ".ArioLauncher")
        self.assertEqual(activity.attrib[ANDROID_NS + "label"], "Ario")
        self.assertEqual(activity.attrib[ANDROID_NS + "icon"], "@mipmap/ario_launcher")
        self.assertEqual(activity.attrib[ANDROID_NS + "taskAffinity"], "ir.souren.souren.ario")
        self.assertEqual(alias.attrib[ANDROID_NS + "icon"], "@mipmap/ario_launcher")
        self.assertEqual(alias.attrib[ANDROID_NS + "targetActivity"], ".ArioActivity")

    def test_ario_startup_uses_ario_wordmark_not_souren_wordmark(self):
        source = (ROOT / "android/lib/main.dart").read_text()
        self.assertIn("widget.initialArioMode\n                        ? const ArioLogo(width: 190, color: pal.ink)\n                        : const SourenLogo(width: 190)", source)

if __name__ == "__main__":
    unittest.main()
