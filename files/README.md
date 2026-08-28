<div align="center">

# 🎮 DualSenseT

**The free, native macOS utility for your PlayStation 5 DualSense controller.**  
Adaptive triggers · LED lightbar · Motion sensors · UDP emulation · Per-app profiles

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/DegenerateUSER/DualsenseT?style=social)](https://github.com/DegenerateUSER/DualsenseT/stargazers)

> A free, open-source macOS alternative to **DualSenseM** and the Windows-only **DualSenseX** — built natively in Swift with zero dependencies.

---

<!-- Replace these with actual screenshots -->
![DualSenseT Dashboard](Assets/screenshot-dashboard.png)

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎯 **Adaptive Triggers** | Configure L2/R2 as Off, Feedback, Weapon, or Vibration — with live preview |
| 💡 **LED Lightbar** | Full color picker + pulse/breathing mode |
| 🗺️ **Live Controller Map** | Real-time button highlights, analog stick grids, dual-finger touchpad trails |
| 🌀 **Motion Sensors** | 3D gyroscope/accelerometer visualization with computed attitude quaternion |
| 🔌 **UDP Server** | DualSenseX-compatible protocol on port `6969` for Wine/CrossOver/GPTK games |
| 🎮 **Per-App Profiles** | Auto-swap controller configs when a game window gets focus |
| 👆 **Touchpad Gestures** | Remap swipe directions to keyboard keys at the virtual HID level |
| ⚡ **Zero-CPU Idle** | 0.0% CPU when dashboard is hidden — sensors disable automatically |
| 🔒 **Background Override** | Keeps adaptive triggers alive via raw IOKit even when app loses focus |
| 📋 **Presets** | Save/load named configs as plain JSON; built-in Bow & Arrow, Rifle, Racing Brake |

---

## 🖥️ System Requirements

- **macOS 13.0 (Ventura)** or newer
- **DualSense** (CFI-ZCT1W) or **DualSense Edge** (CFI-ZCP1)
- Connection via **Bluetooth** or **USB** (both fully supported)

---

## 🚀 Installation

### Option 1 — Download (Recommended)

Download the latest `.dmg` from the [Releases](https://github.com/DegenerateUSER/DualsenseT/releases) page, open it, and drag **DualSenseT.app** to your Applications folder.

> **Note:** On first launch, macOS may block the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Option 2 — Build from Source

```bash
git clone https://github.com/DegenerateUSER/DualsenseT.git
cd DualsenseT
./build.sh
```

The compiled `DualSenseT.app` will appear in the project root.

---

## 🎛️ Usage

### Connecting Your Controller

**Bluetooth:** Pair your DualSense via System Settings → Bluetooth, then launch DualSenseT.  
**USB:** Plug in — it's detected automatically.

The **Menu Bar icon** shows live connection type and battery (`[BT] 85%` or `[USB] 100%`).

### Adaptive Triggers

Open the dashboard → **L2** or **R2** tab → choose a mode:

- **Off** — standard trigger, no resistance
- **Feedback** — stiff spring simulation (set start position + strength)
- **Weapon** — firearm snap-gate feel (start, end, strength)
- **Vibration** — haptic buzz against your finger (position, amplitude, frequency)

The live preview bar updates in real time. Your physical pull position is shown as a blue gauge.

### UDP Server (for Wine / CrossOver / GPTK)

Enable the UDP Server in the **UDP** tab. Games that support DualSenseX triggers (Cyberpunk 2077, Spider-Man, etc.) will send JSON commands to port `6969` and your controller responds with real adaptive trigger feedback.

### Per-App Profiles

Go to **Settings → Per-App Profiles**, assign any preset to a game or app bundle. DualSenseT runs a background observer and swaps configs automatically when you switch to that app.

---

## 🔧 Advanced Engineering

<details>
<summary><b>Adaptive IMU Complementary Filter</b></summary>

The macOS `GameController` framework does not populate the DualSense attitude quaternion (always returns `w:1, x:0, y:0, z:0`). DualSenseT implements a custom **Adaptive Complementary Filter** that fuses raw sensor data in real time:

1. **Gyroscope Integration** — integrates rotation rates around X (pitch), Y (yaw), Z (roll)
2. **Accelerometer Drift Correction** — uses the gravity vector to correct pitch/roll drift
3. **Adaptive Gain** — bypasses accelerometer correction during fast motion (avoids centripetal force corruption); increases gain when stationary
4. **Yaw Auto-Decay** — resting yaw slowly returns to 0.0 to eliminate compass-less drift

</details>

<details>
<summary><b>Raw HID Background Override</b></summary>

The `GameController` framework stops sending output reports when the app loses focus. DualSenseT solves this by:

1. Catching `didResignActiveNotification`
2. Locating the raw `IOHIDDevice` for the controller
3. Computing the DualSense Bluetooth output report, signing it with a **CRC32 checksum**, and writing directly via IOKit — keeping adaptive triggers active while you're in-game

</details>

<details>
<summary><b>Zero-CPU Idle</b></summary>

Controller vibration notifications fire at 150Hz+. DualSenseT dynamically disables motion sensors (`sensorsActive = false`) and bypasses main-thread dispatches whenever the Sensors tab is not visible, resulting in **0.0% idle CPU usage**.

</details>

---

## 🧪 Running Tests

```bash
./build.sh test
```

The test suite covers preset serialization, parameter parsing, touchpad remapping thresholds, and quaternion calculations.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

- 🐛 **Bug?** → [Open an issue](https://github.com/DegenerateUSER/DualsenseT/issues/new?template=bug_report.md)
- 💡 **Feature idea?** → [Start a discussion](https://github.com/DegenerateUSER/DualsenseT/discussions)
- 🔧 **Want to contribute code?** → Fork → branch → PR

---

## ⚠️ Compatibility Notice

DualSenseT uses raw IOKit HID overrides and Bluetooth CRC32 tricks that operate below the standard macOS framework layer. Future macOS updates may require adjustments. If something breaks after a system update, please [open an issue](https://github.com/DegenerateUSER/DualsenseT/issues).

---

## 📄 License

[MIT](LICENSE) © 2026 DegenerateUSER

---

<div align="center">

If DualSenseT is useful to you, consider giving it a ⭐ — it helps others discover it!

</div>
