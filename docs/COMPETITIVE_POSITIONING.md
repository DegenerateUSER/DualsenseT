# Competitive Positioning: Sticky Fingers and DualSenseM

Research date: 4 September 2026.

Primary source: the current
[DualSenseM Mac App Store listing](https://apps.apple.com/us/app/dualsensem/id1598693570?mt=12).
Claims can change; recheck before publishing comparisons.

## What DualSenseM Publicly Offers

The listing advertises:

- USB and Bluetooth controller connections
- Menu-bar connection and battery status
- 20 trigger effects for L2 and R2
- Static and rainbow touchpad lighting
- Player LEDs
- Independent motor tests and strength
- Three mic LED modes
- USB-only speaker, headset, microphone, volume, and Audio Haptics
- An input-test page
- Testing with Steam, Arcade, and Mac App Store games
- macOS 11.3 or newer
- English localization
- Free download with a $3.99 DSM Pro upgrade
- No data collection

The listed public version is 1.0.3, dated 29 December 2021. Its description says the app was
scheduled for a complete remake as of July 2025 and directs users to the DSX Discord for
updates. The App Store says there are not enough ratings for an overview.

## Where Sticky Fingers Is Stronger

These are supportable differentiators, not assumptions about DualSenseM internals.

### Open development

Sticky Fingers publishes complete GPL-3.0-only source, protocol implementation, build and
release scripts, test infrastructure, architecture, privacy behavior, and historical
failure notes. The DualSenseM listing does not link a source repository.

### Inspectability and contributor path

Sticky Fingers has 75 automated regression tests plus structured bug, feature, security,
contribution, and hardware-test workflows. Users can inspect exact USB/Bluetooth report
bytes and contribute fixes for new macOS or firmware behavior.

### Diagnostics

Sticky Fingers includes a live controller map, two-finger touch visualization, battery
state, raw gyro/accelerometer values, and a custom fused 3D attitude view. DualSenseM's
public listing mentions an input page but does not advertise motion fusion or comparable
touch diagnostics.

### Automation and integrations

Sticky Fingers provides reusable presets, automatic per-application profile switching, and
a loopback-only DualSenseX-compatible UDP command interface. These are not advertised in
the current DualSenseM listing.

### Verified modern audio pipeline

Sticky Fingers documents its ScreenCaptureKit/CoreAudio pipeline, planar and interleaved PCM
handling, bounded real-time ring buffer, independent grip channels, and adaptive-trigger
coexistence. The implementation was hardware-tested on a base M1 MacBook Air running macOS
27 Golden Gate.

### Current engineering record

Sticky Fingers has current source history, reproducible tests, and explicit known
limitations. The only version date visible for DualSenseM is 2021, although its listing
announces a remake; do not claim the remake is cancelled or inactive without newer evidence.

## Where DualSenseM Is Stronger

### Installation and trust

DualSenseM is distributed through the Mac App Store, which provides familiar installation,
updates, signing, and discovery. Sticky Fingers will be a GitHub download and still needs
its first Developer ID notarized release to match that level of user confidence.

### Advertised platform reach

DualSenseM advertises macOS 11.3+. Sticky Fingers currently targets macOS 14+ and Apple
silicon. Do not imply broader compatibility until older systems or Intel are intentionally
supported.

### Trigger-effect count

DualSenseM advertises 20 trigger effects. Sticky Fingers exposes 11 editable native modes
and maps 19 DSX instruction types. Counts are not equivalent, but “more modes” is not
currently a safe Sticky Fingers claim.

### Shipping maturity

DualSenseM has an App Store product page, privacy disclosure, established seller identity,
and an existing paid upgrade. Sticky Fingers still needs a clean-install matrix, release
certificate, public screenshots, demo, support process, and real user feedback.

### Tested-game claim

DualSenseM explicitly advertises Steam, Arcade, and Store game testing. Sticky Fingers has
working protocol and background tests, but needs a named, reproducible game compatibility
list before making an equally broad marketing claim.

## Feature Parity

Both products publicly cover the core category:

- USB and Bluetooth controller connectivity
- Adaptive trigger customization
- Light/player/mic LED control
- Rumble tests
- Menu-bar battery/connection status
- USB speaker, headset, microphone, volume, and audio haptics
- Input visualization or testing
- Local/no-data-collection positioning

Parity features should be explained clearly, not marketed as unique.

## Highest-Value Improvements

### Before the first public release

1. Replace the Sony-branded icon with original Sticky Fingers artwork.
2. Complete trademark clearance or choose a more distinctive name.
3. Produce a signed, notarized, stapled, checksummed release.
4. Test clean installation and permissions on macOS 14 and a current stable macOS release.
5. Complete wired-headset, reconnect, sleep/wake, restore-after-stop, and one-hour audio
   haptics tests.
6. Establish the actual DualSense Edge support level.
7. Publish polished screenshots and a short physical-controller demo.

### Product parity and reliability

1. Add a first-run connection and permission walkthrough.
2. Add in-app update checks for GitHub releases, designed without analytics.
3. Build a named game-compatibility matrix with controller, transport, and settings.
4. Expand trigger presets where they create distinct physical behavior—not merely a larger
   count.
5. Add export/import for profiles and safe configuration backup.
6. Add explicit conflict detection or guidance for Steam Input and other HID owners.
7. Add structured, opt-in diagnostic export with automatic privacy redaction.

### Differentiation

1. Community-maintained per-game profiles with reviewable JSON.
2. Audio-haptics equalizer, per-grip balance, compressor/limiter presets, and latency
   calibration.
3. A background status panel showing exactly which profile and output owner are active.
4. More complete remapping where macOS permissions and game compatibility permit it.
5. DualSense Edge paddles/function-button support after hardware research.
6. Localization, keyboard navigation, VoiceOver labels, reduced-motion review, and
   contrast/accessibility testing.

## Comparison Copy That Is Safe to Publish

> Sticky Fingers is an open-source DualSense control studio built natively for modern
> macOS. Alongside triggers, lighting, rumble, and USB audio controls, it adds transparent
> protocol documentation, per-app profiles, a local DSX-compatible integration, motion and
> touch diagnostics, and a hardware-tested system-audio haptics pipeline.

Avoid “better than DualSenseM,” “the only Mac app,” or unqualified feature-count claims.
Let source availability, current verification, automation, and technical depth carry the
comparison.

