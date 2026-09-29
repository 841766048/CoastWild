"""Check the committed project and the project re-integrated by CocoaPods in CI."""
import json
from pathlib import Path
import subprocess
import unittest


class PodsLinkingTests(unittest.TestCase):
    def test_pods_linking_is_owned_by_cocoapods(self):
        root = Path(__file__).resolve().parents[3]
        project = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-",
            str(root / "CoastWild.xcodeproj/project.pbxproj"),
        ]))
        objects = project["objects"]
        target = next(obj for obj in objects.values()
                      if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == "CoastWild")
        linked = []
        for phase_id in target["buildPhases"]:
            phase = objects[phase_id]
            if phase["isa"] != "PBXFrameworksBuildPhase":
                continue
            for build_id in phase.get("files", []):
                ref = objects.get(objects[build_id].get("fileRef"), {})
                if ref.get("path", "").endswith("Pods_CoastWild.framework"):
                    self.assertEqual(ref["isa"], "PBXFileReference",
                                     "XcodeGen must not link the Pods product proxy; CocoaPods owns this link")
                    linked.append(ref["path"])
        self.assertLessEqual(len(linked), 1, "Pods_CoastWild.framework is linked more than once")


if __name__ == "__main__":
    unittest.main()
