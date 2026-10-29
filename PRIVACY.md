# Privacy Policy — NotchFlow

**Last Updated:** October 2026

NotchFlow is built from the ground up with a strict **privacy-first, local-only** architecture.

## 1. Zero Telemetry or Data Collection
- NotchFlow does **not** include any analytics SDKs, crash-reporting trackers, advertising identifiers, or telemetry services.
- NotchFlow does **not** require an account, sign-in, license server, or subscription.

## 2. How Permissions & System Data Are Used
All permissions requested by NotchFlow are contextual, optional, and processed exclusively on your Mac:

1. **Calendar (`EventKit`)**:
   - Used solely to display your upcoming events, live countdowns, video-conference join links, and the interactive monthly calendar inside the Dynamic Island.
   - Your calendar data is never transmitted over the network or stored outside macOS system memory.
2. **Media & Automation (`AppleEvents` / `DistributedNotificationCenter`)**:
   - Used to read Now Playing track metadata (song title, artist, album, artwork, duration) and execute playback commands (`playpause`, `next track`, `previous track`, `seek`) in Apple Music, Spotify, and supported browsers.
   - Spotify album artwork URLs are fetched directly from Spotify's CDN to display cover art in the island.
3. **Location & Weather (`CoreLocation` + Open-Meteo)**:
   - When Weather is enabled, NotchFlow queries the public, key-free [Open-Meteo API](https://open-meteo.com) using either your approximate coordinates (if Location permission is granted), a custom city name you configure, or a regional fallback derived from your system timezone.
   - Weather responses are cached locally for 20 minutes in `UserDefaults` to minimize network requests.
4. **System HUDs (`CoreAudio`, `IOKit`, `IOBluetooth`)**:
   - Volume, display brightness, battery charge state, and connected Bluetooth audio devices are observed locally via macOS frameworks to render Dynamic Island HUD animations.

## 3. Contact
Questions or security inquiries can be raised via the [NotchFlow GitHub Repository](https://github.com/Manateek1/NotchFlow/issues).
