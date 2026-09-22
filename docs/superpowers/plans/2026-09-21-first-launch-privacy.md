# First-launch Privacy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add the approved first-install privacy gate, policy details, and decline sheet before authentication.

**Architecture:** Persist versioned acceptance in an isolated Core store. Route the app to UIKit privacy controllers until consent is accepted, then reuse the existing root flow.

**Tech Stack:** Swift 5, UIKit, UserDefaults, XCTest, XCUITest.

## Global Constraints

- No system permission request occurs on the privacy screen.
- Production and test consent state remain isolated.
- Existing authentication and content routes remain unchanged after acceptance.

### Task 1: Consent persistence

- [x] Add failing versioning and reset tests.
- [x] Implement `PrivacyConsentStore`.
- [x] Run the Core test suite.

### Task 2: UIKit privacy flow

- [x] Gate `CoastEnvironment.showRoot()` on consent.
- [x] Build the full-screen introduction, native policy detail, and decline sheet.
- [x] Add bilingual copy, accessibility identifiers, and Dynamic Type fonts.

### Task 3: UI regression coverage

- [x] Add a first-launch privacy flow UI test.
- [x] Let existing UI tests explicitly pre-accept privacy.
- [x] Regenerate the Xcode project, build, run tests, and capture the implemented screen.
