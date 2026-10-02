"""V1 has photo selection, but no camera, microphone, or calling feature."""
import json
import html
import os
from pathlib import Path
import plistlib
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]
UNUSED_PERMISSIONS = ("NSCameraUsageDescription", "NSMicrophoneUsageDescription")


class NativeCapabilitiesTests(unittest.TestCase):
    def test_shipping_sources_do_not_contain_retired_backend(self):
        for path in (ROOT / "CoastWild").rglob("*"):
            if path.suffix in (".swift", ".plist", ".html"):
                source = path.read_text(encoding="utf-8")
                for token in ("test-app.bigegg.work", "test.duckegg.ios", "IntegrationAPIClient", "remoteSessionCoordinator"):
                    self.assertNotIn(token, source, str(path))

    def test_bundled_legal_html_has_no_audio_video_descriptions(self):
        files = list((ROOT / "CoastWild/Resources/Legal").rglob("*.html"))
        self.assertTrue(files, "Bundled legal documents must exist")
        forbidden = re.compile(
            r"\b(?:audio|videos?|microphones?|cameras?|voice|voip|webcam|"
            r"webrtc|videocalls?|videoconferencing)\b|音频|视频|语音|通话|麦克风|摄像|录音",
            re.IGNORECASE,
        )
        for path in files:
            with self.subTest(document=path.name):
                source = html.unescape(path.read_text(encoding="utf-8"))
                self.assertIsNone(forbidden.search(source), str(path))

    def test_project_has_no_unused_capture_permissions(self):
        project = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-",
            str(ROOT / "CoastWild.xcodeproj/project.pbxproj"),
        ]))
        for obj in project["objects"].values():
            if obj.get("isa") == "XCBuildConfiguration":
                for key in UNUSED_PERMISSIONS:
                    self.assertNotIn("INFOPLIST_KEY_" + key, obj.get("buildSettings", {}))
        spec = (ROOT / "project.yml").read_text()
        for key in UNUSED_PERMISSIONS:
            self.assertNotIn(key, spec)

    def test_both_content_webviews_explicitly_deny_capture(self):
        for name in ("LegalWebController", "LearningWebController"):
            with self.subTest(controller=name):
                source = (ROOT / "CoastWild/UI" / (name + ".swift")).read_text()
                self.assertIn("WKUIDelegate", source)
                self.assertIn("webView.uiDelegate = self", source)
                self.assertIn("requestMediaCapturePermissionFor", source)
                self.assertIn("decisionHandler(.deny)", source)

    @unittest.skipUnless(os.environ.get("COAST_ARCHIVE_ROOT"), "Archive is checked after export in CI")
    def test_exported_app_has_no_unused_capture_permissions(self):
        archive_root = Path(os.environ["COAST_ARCHIVE_ROOT"])
        pattern = ("Products/Applications/*.app/Info.plist" if archive_root.suffix == ".xcarchive"
                   else "**/*.xcarchive/Products/Applications/*.app/Info.plist")
        files = list(archive_root.glob(pattern))
        self.assertTrue(files, "No archived application found; cannot verify final permissions")
        for path in files:
            with path.open("rb") as file:
                info = plistlib.load(file)
            for key in UNUSED_PERMISSIONS:
                self.assertNotIn(key, info, str(path))
            self.assertNotIn("voip", info.get("UIBackgroundModes", []))
            config_path = path.parent / "IntegrationConfig.plist"
            with config_path.open("rb") as file:
                config = plistlib.load(file)
            self.assertEqual(config.get("CoastAuthenticationProvider"), "firebase-anonymous")
            self.assertNotIn("CoastPrimaryHost", config)


if __name__ == "__main__":
    unittest.main()
