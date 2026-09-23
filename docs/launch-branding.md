# App icon and launch appearance

- App icon: user-approved ivory mountain-and-wave design, exported as an opaque 1024 × 1024 PNG to `CoastWild/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- Launch background: solid warm ivory `#F6F0E3`.
- Launch emblem: transparent `LaunchMark` asset, template-rendered in deep teal `#075E73`, 200 × 200 pt, centered in the full view.
- System launch screen: `CoastWild/Resources/LaunchScreen.storyboard`, configured for Debug and Release and in `project.yml`.
- Session recovery: same background and emblem; loading/retry controls sit near the bottom safe area. No artificial launch delay.
- Existing privacy, login and business routing remains unchanged.

The built-in image generation tool produced the transparent emblem from the approved icon. Prompt: preserve the mountain-and-wave silhouette, remove ivory background including negative spaces, use a flat deep-teal emblem on true transparent alpha, no lettering, shadows or frame. Template rendering enforces the final solid color.

Original generated icon: `exec-8b3d4386-b539-4166-8201-78a1d5002b14.png`.
Generated launch emblem: `exec-8152a1eb-f943-431f-b8c2-e37e354c915a.png`.
