# Contributing to NotchFlow

Thank you for your interest in contributing to **NotchFlow**! NotchFlow is a free, open-source Dynamic Island utility for macOS written in native Swift, SwiftUI, and AppKit.

## Getting Started

### Prerequisites
- macOS 15.0 (Sequoia) or newer
- Xcode 16.0 or newer
- Optional: [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) if modifying `project.yml`

### Building & Running Locally
```bash
git clone https://github.com/Manateek1/NotchFlow.git
cd NotchFlow
xcodebuild -project NotchFlow.xcodeproj -scheme NotchFlow -configuration Debug build
```
Or open `NotchFlow.xcodeproj` directly in Xcode and press **Cmd+R**.

### Running Automated Tests
```bash
xcodebuild -project NotchFlow.xcodeproj -scheme NotchFlow -destination 'platform=macOS' test
```

## Architecture Guidelines
1. **Public APIs First**: Prefer documented Apple frameworks (`AppKit`, `SwiftUI`, `EventKit`, `CoreAudio`, `IOKit`, `IOBluetooth`, `CoreLocation`, `ServiceManagement`). Never introduce unsafe private framework hacks that compromise system stability.
2. **Zero Idle CPU**: Avoid continuous polling loops or background timers when the Dynamic Island is idle or paused. Use event-driven observers (`AudioObjectAddPropertyListenerBlock`, `IOPSNotificationCreateRunLoopSource`, `DistributedNotificationCenter`, `.EKEventStoreChanged`).
3. **Modular Media Providers**: New media players should conform to the `MediaProviderDriver` protocol in `NotchFlow/Features/Music/MediaManager.swift`.
4. **Respect macOS Security Boundaries**: Always explain permissions contextually and provide a clean fallback state when a permission is declined.

## Submitting Pull Requests
1. Fork the repository and create a descriptive feature branch (`git checkout -b feat/my-improvement`).
2. Add or update unit tests in `NotchFlowTests/` where applicable.
3. Verify that `xcodebuild ... test` passes cleanly.
4. Open a Pull Request describing your changes and including screenshots or screen recordings for UI updates.
