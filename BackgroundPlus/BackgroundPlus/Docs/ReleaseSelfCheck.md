# Release Self Check

## Automated

- Build app target: `xcodebuild -project BackgroundPlus.xcodeproj -scheme BackgroundPlus -destination 'platform=macOS' build`
- Run unit tests and UI tests before release.
- Ensure localization key parity test passes.

## Manual

- Verify list/details render from `sfltool dumpbtm` output.
- Verify low/medium/high confirmation flows.
- Verify backup folder opens from result page.
- Verify operation history shows backup path.
- Verify Chinese and English UI labels.

## Known limits and mitigation

- BTM internal storage is private and may change across macOS versions.
- Keep DB access behind adapter boundary to isolate future changes.
- Treat parse drift as high-uncertainty signal and elevate confirmation level.
