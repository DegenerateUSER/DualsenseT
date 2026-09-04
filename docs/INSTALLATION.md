# Installing Sticky Fingers

## Requirements

- Apple silicon Mac
- macOS 14 Sonoma or newer
- PlayStation 5 DualSense or DualSense Edge controller
- Data-capable USB cable for controller audio and audio haptics

Standard controller features work over USB and Bluetooth. Controller audio and audio
haptics require USB because the DualSense does not expose an audio device over Bluetooth.

## Install a Release Build

1. Download the latest `Sticky-Fingers-<version>.zip` from the repository's
   [Releases](https://github.com/DegenerateUSER/DualsenseT/releases) page.
2. Extract it.
3. Drag **Sticky Fingers.app** into `/Applications`.
4. Open it from Applications or Spotlight.
5. Keep the app running while you play. Closing its window leaves the Dock and menu-bar
   helper active; quit with `⌘Q`.

Public release archives should be Developer ID signed and notarized. If Gatekeeper reports
that a published release is from an unidentified developer, do not bypass the warning—open
an issue because the release pipeline is incomplete or the archive may not be official.

## Permissions

Sticky Fingers asks only when a feature needs access.

### Screen & System Audio Recording

Required only for **Audio (USB) → Audio Haptics**. ScreenCaptureKit captures system audio
locally and converts it into controller vibration. The app does not save or transmit video
or audio.

Grant under:

```text
System Settings → Privacy & Security → Screen & System Audio Recording
```

Quit and reopen Sticky Fingers after changing this permission.

### Accessibility

Required only when touchpad swipe gestures are mapped to keyboard actions.

Grant under:

```text
System Settings → Privacy & Security → Accessibility
```

### Input Monitoring

macOS may request Input Monitoring for raw controller input. Grant it only to the official
build you installed.

## USB Audio Setup

1. Connect the controller through USB.
2. Open **Audio (USB)**.
3. Sticky Fingers should report the controller as Ready.
4. If asked, select **Configure Quadraphonic**. The required order is:
   Front L, Front R, Haptic L, Haptic R.
5. Start Audio Haptics and grant system-audio permission.

Changing the Mac's default speaker is not required.

## Build From Source

Install the Xcode Command Line Tools:

```bash
xcode-select --install
```

Clone and build:

```bash
git clone https://github.com/DegenerateUSER/DualsenseT.git
cd DualsenseT
./build.sh test
./build.sh
open "Sticky Fingers.app"
```

Local builds are ad-hoc signed unless `CODESIGN_IDENTITY` is provided. macOS ties privacy
grants to signing identity, so an ad-hoc rebuild may require Screen & System Audio Recording
permission again.

For a stable development identity:

```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./build.sh
```

## Data and Uninstall

Presets and logs are stored in:

```text
~/Library/Application Support/Sticky Fingers/
```

On first run, existing data from `~/Library/Application Support/DualSenseT/` is copied when
the new folder does not yet exist.

To uninstall:

1. Quit Sticky Fingers.
2. Delete `Sticky Fingers.app`.
3. Optionally delete its Application Support folder and remove its Privacy & Security
   permissions.

