import pathlib
import unittest
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        path = ROOT / "codemagic.yaml"
        self.assertTrue(path.exists(), "Codemagic workflow configuration is missing")
        self.workflows = yaml.safe_load(path.read_text())["workflows"]

    def test_only_v1_workflows_and_pinned_toolchain(self):
        self.assertEqual(set(self.workflows), {"dev-checks", "main-ipa"})
        for workflow in self.workflows.values():
            self.assertEqual(workflow["environment"]["xcode"], "26.1.1")
            self.assertEqual(workflow["environment"]["cocoapods"], "1.16.2")

    def test_push_only_development_branch_without_secrets(self):
        dev = self.workflows["dev-checks"]
        self.assertEqual(dev["triggering"]["events"], ["push"])
        self.assertEqual(dev["triggering"]["branch_patterns"], [{"pattern": "codex/native-uikit", "include": True, "source": True}])
        self.assertNotIn("groups", dev["environment"])
        self.assertNotIn("ios_signing", dev["environment"])
        self.assertNotIn("integrations", dev)
        self.assertNotIn("publishing", dev)

    def test_main_uploads_with_integration_without_automatic_review(self):
        main = self.workflows["main-ipa"]
        self.assertEqual(main.get("integrations"), {
            "app_store_connect": "CoastWild-NewAccount",
        })
        self.assertEqual(main.get("publishing"), {
            "app_store_connect": {
                "auth": "integration",
                "submit_to_testflight": False,
                "submit_to_app_store": False,
            },
        })

    def test_main_manual_only_and_exact_signing(self):
        main = self.workflows["main-ipa"]
        self.assertNotIn("triggering", main)
        self.assertEqual(main["environment"]["ios_signing"], {"distribution_type": "app_store", "bundle_identifier": "com.huankecontact.coastwild"})
        self.assertIn("test backend", main["name"])

    def test_steps_start_with_context_guard_and_have_tests(self):
        for key, workflow in self.workflows.items():
            scripts = [item["script"] for item in workflow["scripts"]]
            self.assertIn("ci_support.py preflight " + key, scripts[0])
            self.assertTrue(any("run.sh checks" in command for command in scripts))
            self.assertTrue(any("run.sh dependencies" in command for command in scripts))


if __name__ == "__main__":
    unittest.main()
