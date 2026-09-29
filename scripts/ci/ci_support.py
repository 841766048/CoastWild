"""Fail-closed checks for the initial, test-backend Codemagic workflows."""
import json
import os
import pathlib
import plistlib
import sys
from urllib.parse import urlparse

BUNDLE_ID = "com.huankecontact.test"
TEAM_ID = "8S59A5XCJ9"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_context(workflow, env, config, firebase):
    branches = {"dev-checks": "codex/native-uikit", "main-ipa": "main"}
    require(workflow in branches, "Unknown workflow")
    require(env.get("CM_BRANCH") == branches[workflow], "Workflow does not match the selected branch")
    require(env.get("CM_PULL_REQUEST", "false") != "true", "These workflows do not accept pull-request builds")
    require(config.get("CoastIntegrationMode") == "development", "This workflow is for the test backend only; configure a separate reviewed production workflow")
    require(config.get("CoastExpectedBundleIdentifier") == BUNDLE_ID, "Integration bundle ID mismatch")
    require(firebase.get("BUNDLE_ID") == BUNDLE_ID, "Firebase bundle ID mismatch")
    for key in ("CoastPrimaryHost", "CoastPrivacyURL", "CoastTermsURL"):
        value = config.get(key)
        require(isinstance(value, str) and bool(value.strip()), "Missing URL: " + key)
        url = urlparse(value)
        require(url.scheme == "https" and bool(url.hostname) and not url.username and not url.password, "Invalid HTTPS URL: " + key)
    require(config.get("CoastPrimaryHost") == "https://test-app.bigegg.work", "Unexpected test API host")
    app_id = config.get("CoastAppStoreID", "")
    require(isinstance(app_id, str) and app_id.isascii() and app_id.isdigit(), "App Store ID must be numeric (not used for publishing by this workflow)")
    if workflow == "dev-checks":
        return None
    require(env.get("CM_TRIGGER_SOURCE") == "api", "IPA export must be started manually in Codemagic")
    number = env.get("PROJECT_BUILD_NUMBER", "")
    require(number.isascii() and number.isdigit(), "Missing/invalid PROJECT_BUILD_NUMBER")
    result = 1000 + int(number)
    require(1000 <= result <= 9999, "Build number exhausted the configured 1000..9999 range; review versioning before continuing")
    return result


def validate_export(options):
    require(options.get("method") in ("app-store", "app-store-connect"), "Expected App Store distribution signing")
    require(options.get("teamID") == TEAM_ID, "Export signing team mismatch")
    require(bool(options.get("provisioningProfiles", {}).get(BUNDLE_ID)), "No matching provisioning profile; configure Codemagic Code signing identities")


def validate_signing_settings(settings):
    app = next((entry.get("buildSettings", {}) for entry in settings if entry.get("target") == "CoastWild"), None)
    require(app is not None, "App build settings missing")
    require(app.get("PRODUCT_BUNDLE_IDENTIFIER") == BUNDLE_ID, "Effective bundle ID mismatch")
    require(app.get("DEVELOPMENT_TEAM") == TEAM_ID, "Effective device signing team mismatch")
    require("Distribution" in app.get("CODE_SIGN_IDENTITY", ""), "Distribution certificate was not applied; use a manually created App Store profile, not an Xcode-managed profile")
    profile = app.get("PROVISIONING_PROFILE_SPECIFIER", "")
    require(bool(profile) and profile != "huankeProfileDev", "No explicit App Store profile applied; replace the local development/Xcode-managed profile with a manually created distribution profile")


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "preflight" and len(sys.argv) == 3:
        with (root / "CoastWild/Resources/IntegrationConfig.plist").open("rb") as file:
            config = plistlib.load(file)
        with (root / "CoastWild/Resources/GoogleService-Info.plist").open("rb") as file:
            firebase = plistlib.load(file)
        build_number = validate_context(sys.argv[2], os.environ, config, firebase)
        if build_number is not None:
            env_file = os.environ.get("CM_ENV")
            require(bool(env_file), "CM_ENV is required to share the cloud build number")
            with open(env_file, "a", encoding="utf-8") as file:
                file.write(f"\nCOAST_BUILD_NUMBER={build_number}\n")
        print("Preflight passed: test backend; no automatic TestFlight/App Store publishing.")
    elif command == "export" and len(sys.argv) == 3:
        with open(sys.argv[2], "rb") as file:
            validate_export(plistlib.load(file))
        print("Export signing configuration verified.")
    elif command == "signing" and len(sys.argv) == 3:
        with open(sys.argv[2], encoding="utf-8") as file:
            validate_signing_settings(json.load(file))
        print("Effective device signing settings verified.")
    else:
        raise ValueError("usage: ci_support.py preflight <dev-checks|main-ipa> | export <plist> | signing <json>")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        print(f"CI configuration error: {error}", file=sys.stderr)
        sys.exit(1)
