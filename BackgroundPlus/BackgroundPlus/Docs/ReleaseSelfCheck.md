# Release Self Check

## Automated

- Build app target: `xcodebuild -project BackgroundPlus.xcodeproj -scheme BackgroundPlus -destination 'platform=macOS' build`
- Run unit tests and UI tests before release.
- Ensure localization key parity test passes.

## Manual

- Verify Settings -> Helper Setup shows install state and retry action.
- Verify helper install failure message is readable and actionable.
- Verify list/details render from `sfltool dumpbtm` output.
- Verify low/medium/high confirmation flows.
- Verify backup folder opens from result page.
- Verify operation history shows backup path.
- Verify Chinese and English UI labels.

## Known limits and mitigation

- BTM internal storage is private and may change across macOS versions.
- Keep DB access behind adapter boundary to isolate future changes.
- Treat parse drift as high-uncertainty signal and elevate confirmation level.
- SMJobBless requires valid code signing pair between app and helper; local debug signing may install-fail.
- If helper install fails, check bundle identifier, helper plist label, and signing consistency first.
