# Changelog

All notable changes to **NotchFlow** will be documented in this file.

## [1.0.0] — 2026-10-28

### Added
- **Core Dynamic Island Engine**:
  - Non-activating `NotchIslandPanel` (`NSPanel`) anchored to the MacBook hardware camera notch (`NSScreen.safeAreaInsets` + `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`) with automatic Floating Pill Mode on notchless displays.
  - Custom `PassthroughHostingView` hit-testing so clicks and cursor hover outside the active island geometry pass transparently to the macOS menu bar and underlying windows.
  - Multi-monitor support, automatic display change repositioning, and full-screen app auto-hide detection.
  - Support for 10 island states: Hidden, Minimal Idle, Compact Pill, Duo Mode, QuickPeek Notification, System HUD, Music Activity, Calendar Activity, Lock Activity, and Expanded Panel.
- **Music & Now Playing System**:
  - Event-driven integration with **Apple Music** (`com.apple.Music.playerInfo`) and **Spotify** (`com.spotify.client.PlaybackStateChanged`), plus optional Web Browser support (`MediaProviderDriver`).
  - Full interactive playback controls: Play/Pause, Next, Previous, interactive progress scrubbing, shuffle, repeat (`off`/`all`/`one`), favorite/like, podcast playback speed, and inline output volume bar.
  - Dominant color extraction from album artwork, ambient glow, pause dimming, audio format badges (`Lossless`, `Dolby Atmos`, `Explicit`, `Podcast`), and 4 live waveform styles (`Harmonic Equalizer Bars`, `Fluid Sine Wave`, `Spectrum Matrix`, `Minimal Beat Pulse`).
- **Calendar & Weather Integration**:
  - Native `EventKit` integration with multi-calendar selection, real-time `.EKEventStoreChanged` updates, live meeting countdowns, 1-click video call `Join` buttons (Zoom, Google Meet, Teams, Webex, FaceTime), and an interactive monthly calendar grid.
  - Zero-API-key Weather widget powered by `CoreLocation` and Open-Meteo with °F/°C support, custom city geocoding, 20-minute response caching, and empty-calendar-day weather summaries.
- **System HUDs & QuickPeek Queue**:
  - Event-driven Dynamic Island HUDs for **Volume & Mute** (`CoreAudio`), **Display Brightness** (`IOKit`), **Battery & Charging / Low Power Mode** (`IOPowerSources`), **Bluetooth & AirPods Connectivity** (`IOBluetooth` + `IORegistry` battery levels), and **Focus Mode**.
  - Priority-queued QuickPeek banner notifications and elastic HUD overshoot spring animations.
- **Settings, Onboarding & CI**:
  - 8-tab native SwiftUI Settings application (`General`, `Appearance`, `Behavior`, `Music & Media`, `Calendar & Weather`, `System HUDs` with interactive test bench, `Permissions`, and `About`).
  - Contextual 6-step First-Launch Onboarding flow.
  - Automated XCTest suite (`NotchFlowTests`) and GitHub Actions CI workflow.
