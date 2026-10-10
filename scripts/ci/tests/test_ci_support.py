import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
MODULE = ROOT / "scripts/ci/ci_support.py"


class CISupportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not MODULE.exists():
            return
        spec = importlib.util.spec_from_file_location("ci_support", MODULE)
        cls.support = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.support)

    def setUp(self):
        self.assertTrue(MODULE.exists(), "CI preflight implementation is missing")
        self.config = {
            "CoastAuthenticationProvider": "firebase-anonymous",
            "CoastExpectedBundleIdentifier": "com.huankecontact.coastwild",
            "CoastPrivacyURL": "https://docs.google.com/document/d/privacy/edit",
            "CoastSupportURL": "https://docs.google.com/document/d/support/edit",
            "CoastTermsResource": "terms-en",
        }
        self.firebase = {"BUNDLE_ID": "com.huankecontact.coastwild"}
        self.env = {"CM_BRANCH": "main", "CM_TRIGGER_SOURCE": "api", "PROJECT_BUILD_NUMBER": "7"}

    def test_old_firebase_config_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Firebase bundle ID mismatch"):
            self.support.validate_context("main-ipa", self.env, self.config, {"BUNDLE_ID": "com.huankecontact.test"})

    def test_manual_main_build_gets_global_increment(self):
        self.assertEqual(self.support.validate_context("main-ipa", self.env, self.config, self.firebase), 1007)

    def test_main_rejects_auto_trigger_wrong_branch_and_pr(self):
        for changed in ({"CM_TRIGGER_SOURCE": "webhook"}, {"CM_BRANCH": "codex/native-uikit"}, {"CM_PULL_REQUEST": "true"}):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                self.support.validate_context("main-ipa", dict(self.env, **changed), self.config, self.firebase)

    def test_dev_needs_no_signing_or_build_number(self):
        self.assertIsNone(self.support.validate_context("dev-checks", {"CM_BRANCH": "codex/native-uikit"}, self.config, self.firebase))

    def test_other_workflow_and_v2_are_rejected(self):
        for workflow, branch in (("unknown", "main"), ("dev-checks", "codex/native-coin-learning")):
            with self.subTest(workflow=workflow), self.assertRaises(ValueError):
                self.support.validate_context(workflow, {"CM_BRANCH": branch}, self.config, self.firebase)

    def test_build_number_missing_malformed_or_out_of_range_rejected(self):
        for number in ("", "-1", "1;echo hello", "1.5", "9000"):
            with self.subTest(number=number), self.assertRaises(ValueError):
                self.support.validate_context("main-ipa", dict(self.env, PROJECT_BUILD_NUMBER=number), self.config, self.firebase)

    def test_config_mismatch_and_insecure_url_rejected(self):
        for key, value in (("CoastAuthenticationProvider", "business"), ("CoastExpectedBundleIdentifier", "other.app"), ("CoastPrivacyURL", "http://example.com"), ("CoastSupportURL", ""), ("CoastTermsResource", "remote"), ("CoastPrimaryHost", "https://retired.example")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.support.validate_context("main-ipa", self.env, dict(self.config, **{key: value}), self.firebase)
        with self.assertRaises(ValueError):
            self.support.validate_context("main-ipa", self.env, self.config, {"BUNDLE_ID": "other.app"})

    def test_export_requires_matching_team_profile_and_distribution(self):
        options = {"method": "app-store-connect", "teamID": "T4VGJVH22P", "provisioningProfiles": {"com.huankecontact.coastwild": "profile-id"}}
        self.support.validate_export(options)
        for key, value in (("method", "development"), ("teamID", "OTHER"), ("teamID", "8S59A5XCJ9"), ("provisioningProfiles", {})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.support.validate_export(dict(options, **{key: value}))

    def test_effective_device_signing_rejects_local_development_profile(self):
        settings = [{"target": "CoastWild", "buildSettings": {
            "PRODUCT_BUNDLE_IDENTIFIER": "com.huankecontact.coastwild", "DEVELOPMENT_TEAM": "T4VGJVH22P",
            "CODE_SIGN_IDENTITY": "Apple Distribution: Coast", "PROVISIONING_PROFILE_SPECIFIER": "App Store profile",
        }}]
        self.support.validate_signing_settings(settings)
        settings[0]["buildSettings"]["PROVISIONING_PROFILE_SPECIFIER"] = "huankeProfileDev"
        with self.assertRaises(ValueError):
            self.support.validate_signing_settings(settings)


if __name__ == "__main__":
    unittest.main()
