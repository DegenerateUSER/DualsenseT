# Open-Source Launch Checklist

This is the release gate for Sticky Fingers. Checked items must represent observed evidence,
not planned work.

## Product Identity

- [x] Public in-app name changed to Sticky Fingers.
- [x] Bundle output changed to `Sticky Fingers.app`.
- [x] Stable bundle identifier selected: `com.degenerateuser.stickyfingers`.
- [x] Existing DualSenseT presets migrate on first run.
- [x] Confirmed the current app icon contains no old product-name text.
- [x] Replaced the detailed DualSense/PlayStation-logo artwork with the original 3A generic
  controller mark; vector source and reproducible `.icns` generator are included.
- [ ] Rename the GitHub repository slug or intentionally keep the legacy URL, then update
  public links.
- [ ] Reserve the intended domain and social handles before announcement.
- [ ] Perform professional trademark clearance for “Sticky Fingers.”

Naming note: an exact-name Balatro mod, a similarly named macOS utility, App Store products,
and unrelated live trademarks were found during the preliminary search. The owner chose to
continue with Sticky Fingers. This is not a legal clearance.

## Core Hardware

- [x] DualSense adaptive triggers tested over USB.
- [x] DualSense adaptive triggers tested over Bluetooth.
- [x] Lightbar, player LEDs, mic LED, and classic rumble tested over USB and Bluetooth.
- [x] Inputs, touchpad, battery, gyro, and accelerometer tested.
- [x] Live Map redesign completed.
- [ ] Verify that native games and Steam still receive Bluetooth input while Sticky Fingers
  owns its exclusive raw-HID session.
- [ ] Retest the cleaned Audio page on hardware.
- [ ] Test disconnect/reconnect during active trigger, LED, and haptic settings.
- [ ] Test sleep/wake and Bluetooth reconnect.
- [ ] Decide whether DualSense Edge is fully supported, experimental, or unverified.

## USB Audio and Audio Haptics

- [x] Four-channel CoreAudio device discovery.
- [x] Quadraphonic setup.
- [x] Controller speaker and microphone.
- [x] Independent Haptic L and Haptic R.
- [x] System-audio capture and response meter.
- [x] Audio haptics plus adaptive triggers simultaneously.
- [x] Audio haptics continue across tab changes.
- [ ] Test a wired 3.5 mm headset.
- [ ] Run audio haptics continuously for at least 60 minutes and record CPU/memory.
- [ ] Disconnect/reconnect USB while audio haptics are running.
- [ ] Verify classic rumble is restored after stop, failure, disconnect, and quit.
- [ ] Verify first-run and revoked Screen & System Audio Recording permissions.

## Platform Matrix

- [x] Build target is arm64 macOS 14+.
- [x] Hardware-verified on base M1 MacBook Air running macOS 27 Golden Gate.
- [ ] Clean-install test on macOS 14 Sonoma.
- [ ] Clean-install test on macOS 15 Sequoia or newer stable release.
- [ ] Test on a second Apple silicon Mac if available.
- [ ] State Intel support as unavailable; do not publish a universal-build claim.

## Automated Quality

- [x] 75 automated tests cover model, transport, background, audio, and security boundaries.
- [x] Local test suite passes.
- [x] Local application build succeeds.
- [x] Bundle name, identifier, arm64 executable, embedded licenses, and ad-hoc development
  signature validate.
- [x] Renamed app launches and quits cleanly.
- [x] Shell scripts and GitHub YAML parse successfully.
- [x] CI workflow added.
- [ ] CI passes from a clean GitHub runner.
- [ ] Signed release workflow succeeds with repository secrets.

## Security and Privacy

- [x] UDP peers are restricted to loopback.
- [x] System audio is processed in memory and excluded from logs/storage.
- [x] Privacy documentation lists permissions, storage, and networking.
- [x] Private vulnerability reporting instructions are present.
- [x] No analytics or telemetry dependency is included.
- [ ] Review logs from a normal session for sensitive or excessively noisy data.
- [ ] Run a final security-focused code review before tagging.

## Open-Source Repository

- [x] GPL-3.0 license included.
- [x] HIDAPI third-party notice included.
- [x] README has positioning, compatibility, setup, and documentation links.
- [x] Installation, troubleshooting, architecture, privacy, and release docs added.
- [x] Contribution and security policies added.
- [x] Bug, feature, and pull request templates added.
- [x] Changelog established.
- [ ] Remove development archives and agent-only working files from the public branch.
- [ ] Confirm every tracked asset can be redistributed under GPL-compatible terms.
- [ ] Enable private vulnerability reporting.
- [ ] Optionally enable GitHub Discussions before directing the community there.
- [ ] Add a code of conduct after selecting a private conduct-reporting contact.
- [ ] Add repository description, topics, social preview, and website URL.

## Marketing Assets

Do not reuse screenshots containing the old DualSenseT name or visible implementation
counters.

- [x] App icon at 1024×1024 and `.icns`.
- [ ] GitHub social preview at 1280×640.
- [ ] Main dashboard screenshot.
- [ ] Adaptive trigger screenshot.
- [ ] Lightbar and haptics screenshot.
- [ ] Clean Audio Haptics screenshot.
- [ ] Live Map screenshot.
- [ ] 20–40 second demo showing Bluetooth triggers and USB audio haptics.
- [ ] Screenshot alt text and captions.

## Release Day

- [ ] Freeze user-facing strings.
- [ ] Update version and changelog.
- [ ] Create signed source tag.
- [ ] Build, sign, notarize, staple, and checksum.
- [ ] Verify on a clean account before publishing.
- [ ] Publish release notes with explicit known limitations.
- [ ] Publish announcement copy and demo.
- [ ] Monitor issues without silently changing release artifacts.

