import pathlib
import unittest
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def test_manual_v2_upload_only(self):
        path = ROOT / "codemagic.yaml"
        self.assertTrue(path.exists(), "V2 workflow configuration missing")
        workflows = yaml.safe_load(path.read_text())["workflows"]
        self.assertEqual(set(workflows), {"v2-ipa"})
        workflow = workflows["v2-ipa"]
        self.assertNotIn("triggering", workflow)
        self.assertEqual(workflow["integrations"], {"app_store_connect": "CoastWild-NewAccount"})
        self.assertEqual(workflow["publishing"], {"app_store_connect": {
            "auth": "integration", "submit_to_testflight": False, "submit_to_app_store": False,
        }})
        self.assertEqual(workflow["environment"]["ios_signing"], {
            "distribution_type": "app_store", "bundle_identifier": "com.huankecontact.coastwild",
        })
        scripts = [step["script"] for step in workflow["scripts"]]
        self.assertEqual(scripts[0], "python3 scripts/ci/ci_support.py preflight v2-ipa")
        self.assertIn("bash scripts/ci/run.sh checks", scripts)
        self.assertIn("bash scripts/ci/run.sh archive", scripts)


if __name__ == "__main__":
    unittest.main()
