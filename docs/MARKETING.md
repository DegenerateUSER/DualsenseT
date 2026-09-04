# Sticky Fingers Launch Playbook

This document keeps public claims consistent with tested behavior. It is internal launch
guidance, not legal advice.

## Positioning

### Category

Native open-source DualSense control studio for macOS.

### One-line description

Sticky Fingers brings adaptive triggers, lighting, controller diagnostics, profiles, and
USB audio haptics to DualSense controllers on Mac.

### Short pitch

Make a DualSense feel at home on macOS. Tune adaptive triggers over USB or Bluetooth, build
profiles that follow your games, inspect every input live, and turn system audio into
independent left/right grip feedback—all in a native, privacy-first GPL app.

### Primary audience

1. Mac gamers using native games, Steam, CrossOver, Wine, or Game Porting Toolkit.
2. DualSense owners who want controller features without a Windows utility.
3. Mod authors who need a local DualSenseX-compatible UDP target.
4. Developers researching controller HID, motion, and audio behavior.

## Message Pillars

### The controller features Mac users are missing

Proof:

- 11 adaptive-trigger modes
- Lightbar, player LEDs, mic LED, and classic rumble
- USB and Bluetooth HID output
- Presets and per-app switching

### Audio you can feel

Proof:

- Quadraphonic DualSense USB setup
- Independent left/right haptic channels
- Local system-audio DSP
- Simultaneous audio haptics and adaptive triggers

Always say **USB audio haptics**. Never imply that controller audio works over Bluetooth.

### Built for macOS, not wrapped for it

Proof:

- SwiftUI and AppKit
- CoreAudio, ScreenCaptureKit, GameController, and IOKit
- Dock and menu-bar behavior
- Background profiles with UI work paused when hidden

### Open and inspectable

Proof:

- GPL-3.0 source
- Public build and release scripts
- 75 automated tests
- No analytics, account, or cloud service

## Differentiation

Lead with what Sticky Fingers demonstrably offers:

- Open source and locally auditable.
- Adaptive trigger output hardware-tested over Bluetooth and USB.
- System-audio-to-haptics integration.
- Live motion and touch visualization.
- DualSenseX-compatible local integration.
- Native macOS background behavior and low-overhead hidden UI.

Do not claim another product lacks a feature unless its current public documentation or a
repeatable test proves it. Avoid “first,” “only,” “zero CPU,” “all Macs,” or “full DualSense
Edge support” until independently verified.

Use the sourced [`COMPETITIVE_POSITIONING.md`](COMPETITIVE_POSITIONING.md) before writing
DualSenseM comparisons.

## GitHub Metadata

Suggested description:

> Native open-source DualSense control studio for macOS—adaptive triggers, lighting,
> profiles, diagnostics, and USB audio haptics.

Suggested topics:

```text
dualsense macos swift swiftui adaptive-triggers controller haptics
game-controller bluetooth hidapi coreaudio screencapturekit gaming
```

Pin these links near the top of the repository:

- Latest release
- Installation
- Privacy
- Changelog
- Contributing

## Screenshot Storyboard

Use one clear action per image. Hide Advanced Diagnostics unless the image documents support
work.

1. **Overview** — connected controller, sidebar, and a recognizable configured state.
2. **Adaptive Triggers** — different L2/R2 modes with the live pull gauge.
3. **Controller Identity** — custom lightbar plus player/mic LEDs.
4. **Audio Haptics** — clean Audio page, running state, intensity, and response meter.
5. **Live Map** — sticks, buttons, touchpad, and LEDs reacting to the controller.
6. **Automation** — presets and per-app profiles.

Export screenshots at consistent window size and display scale. Do not show usernames,
bundle IDs, logs, serial numbers, implementation stages, or test counters.

## Demo Video: 30 Seconds

1. `0–4s`: Title and controller connecting over Bluetooth.
2. `4–10s`: Apply a Weapon trigger preset; show physical trigger reaction.
3. `10–15s`: Change the lightbar and player LEDs.
4. `15–20s`: Show Live Map responding to buttons, sticks, and touch.
5. `20–27s`: Connect USB, start Audio Haptics, and show both grips reacting while triggers
   remain active.
6. `27–30s`: “Native. Local. Open source.” plus repository URL.

Use captions because many social feeds autoplay muted. Do not use copyrighted game/music
footage without permission.

## Announcement Copy

### Short

> Sticky Fingers is an open-source DualSense control studio for Apple silicon Macs:
> adaptive triggers over USB and Bluetooth, lighting, profiles, live diagnostics, and USB
> system-audio haptics. Built natively in Swift and processed locally.

### Launch Post

> I built Sticky Fingers because using the DualSense on macOS should mean more than basic
> buttons and sticks. It can tune adaptive triggers over USB or Bluetooth, control lighting
> and rumble, switch profiles with your games, visualize touch and motion, and—over
> USB—convert system audio into independent left/right grip haptics.
>
> It is native Swift/SwiftUI, GPL-3.0, hardware-tested on an M1 MacBook Air, and has no
> account, analytics, or cloud backend. The first release includes signed/notarized binaries
> plus complete source and technical documentation.

Add the real release URL and demo only after the notarized artifact passes a clean install.

## FAQ Copy

### Does it work over Bluetooth?

Adaptive triggers, lights, rumble, input, touch, motion, battery, profiles, and Live Map do.
Controller speaker, microphone, headset, and audio haptics require USB.

### Does it keep working while a game is focused?

Yes. Controller output, profiles, UDP, and an active audio-haptics stream are app-wide
services. Closing the main window does not quit the app.

### Is system audio uploaded?

No. ScreenCaptureKit supplies audio only while Audio Haptics is active; processing happens
in memory on the Mac and nothing is recorded or transmitted.

### Which Macs are supported?

The current build targets Apple silicon and macOS 14 or newer. Publish broader claims only
after the platform matrix is tested.

### Is DualSense Edge supported?

Do not promise full Edge support until the launch checklist records a complete hardware
pass. State the exact tested subset.

## Launch Sequence

1. Complete the hardware and platform gates.
2. Capture final screenshots and demo from the signed release candidate.
3. Publish the GitHub release and verify downloads.
4. Post to relevant macOS, open-source, controller, and game-compatibility communities.
5. Ask early users for reproducible hardware reports, not generic ratings.
6. Convert recurring setup questions into documentation before adding features.

## Brand Risk Record

“Sticky Fingers” has existing uses in software, games, the App Store, entertainment, and
registered marks in unrelated industries. Search collisions will make discovery harder, and
a preliminary web search is not trademark clearance. Complete a jurisdiction-appropriate
trademark review before investing in paid promotion, domains, or merchandise.

