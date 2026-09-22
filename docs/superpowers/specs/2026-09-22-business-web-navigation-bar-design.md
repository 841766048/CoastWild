# Business Web Navigation Bar Design

## Goal

The primary business WebView must occupy the full application content area without displaying the navigation bar. The status bar and Home Indicator remain unchanged.

## Behavior

- `BusinessWebController` hides its containing navigation controller's navigation bar whenever the controller is about to appear.
- An internal WebView may temporarily show or hide the navigation bar according to its existing `showsNavigationBar` contract.
- When an internal WebView is popped and the primary business WebView appears again, the primary controller hides the navigation bar again.
- Leaving the business WebView flow does not impose hidden-navigation state on unrelated native flows; those flows retain their existing navigation setup.

## Implementation

Add a `viewWillAppear(_:)` override to `BusinessWebController`. After calling `super`, it calls `setNavigationBarHidden(true, animated:)` on its current navigation controller. Keep the root-navigation setup in `AppDelegate` as an initial-state safeguard.

No Web URL selection, JavaScript bridge, safe-area, status-bar, or internal-WebView behavior changes are included.

## Verification

- Add a focused lifecycle test that embeds `BusinessWebController` in a navigation controller, makes the navigation bar visible, triggers appearance, and verifies that the bar becomes hidden.
- Run the focused test first and confirm it fails before production code changes.
- Run the complete relevant test suite after implementation.
