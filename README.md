# Useful Travel Clock: GitHub integration

This package preserves the uploaded repository's target names, bundle IDs, App Group, city database and MIT license. It does not contain signing keys or profiles.

## Install
Copy the CONTENTS of this folder into the root of nrtak/usefultravelclock, including the hidden .github folder, and commit on a new branch. Do not nest this folder inside the repository. Review the changes before merging.

## Run in order
1. Run “iOS build and tests” and address compiler/test errors first.
2. Add a proper iOS AppIcon asset catalog before distribution. The imported repository does not include one.
3. Once the build passes, run “Upload to TestFlight” manually from Actions. It uses the seven configured secrets and Team ID R3233N87DC. It archives both targets and uploads to App Store Connect; processing and tester assignment happen in TestFlight afterwards.
4. Build numbers use the upload workflow run number. If the app already has a higher build number, adjust the versioning before uploading.

## Changes
- Corrected Canvas paths, missing widget database references, invalid String.flatMap use, and Codable declarations.
- Corrected settings persistence and widget refresh requests.
- Moved Add city into Clocks; added city management and always-visible reset.
- Added display preferences and automatic spacing.
- Corrected converter date/time picker time zones, invalid-time handling, and stale results. Repeated DST times select the first occurrence.
- Added XCTest coverage and simulator CI, plus manual signing/upload workflow.

## Validation status
Source review only on Windows; no successful Xcode build or TestFlight upload is claimed. CI must compile and run the tests. The imported widget layouts remain the existing small/six-city-medium/accessory versions; full parity with the latest web prototype, including Travel Mode and revised widgets, remains follow-up work. Use this integrated package instead of combining it with the separate earlier SwiftUI starter, which would introduce duplicate app/model types.
