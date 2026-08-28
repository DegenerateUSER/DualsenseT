# DualSenseT User Manual & Technical Documentation

DualSenseT is a high-performance, open-source macOS utility designed to customize, test, monitor, and emulate the PlayStation 5 DualSense and DualSense Edge controllers. It serves as a native macOS alternative to paid software like *DualSenseM* and Windows-only utilities like *DualSenseX*.

The application operates in a dual mode: as a lightweight system **Menu Bar Helper** that runs persistently in the background, and as a rich **SwiftUI Dashboard** offering granular customization and real-time sensor diagnostics.

---

## Table of Contents
1. [System Requirements & Setup](#system-requirements--setup)
2. [Dual-Mode Architecture](#dual-mode-architecture)
3. [Tab-by-Tab Dashboard Guide](#tab-by-tab-dashboard-guide)
   * [Left Trigger (L2) & Right Trigger (R2)](#1-left-trigger-l2--right-trigger-r2)
   * [Lightbar](#2-lightbar)
   * [Haptics (Rumble, Mic LED, Player LEDs)](#3-haptics)
   * [Live Map (Visualizer)](#4-live-map-visualizer)
   * [Sensors (Gyroscope & Accelerometer)](#5-sensors-gyroscope--accelerometer)
   * [UDP Server](#6-udp-server)
   * [Presets](#7-presets)
   * [Settings (Touchpad Gestures & Profiles)](#8-settings)
4. [Advanced Engineering Features](#advanced-engineering-features)
   * [Adaptive IMU Complementary Filter](#adaptive-imu-complementary-filter)
   * [Zero-CPU Idle Optimization](#zero-cpu-idle-optimization)
   * [Raw HID Background Override](#raw-hid-background-override)
5. [Compilation & Unit Testing](#compilation--unit-testing)

---

## System Requirements & Setup

* **Operating System:** macOS 13.0 (Ventura) or newer.
* **Supported Hardware:** PlayStation 5 DualSense Controller (CFI-ZCT1W) or DualSense Edge Controller (CFI-ZCP1).
* **Connection Type:**
  * **Bluetooth (Wireless):** Supported for all features (Adaptive Triggers, LED Lightbar, Rumble, Mic LED, Touchpad, Gyro/Accel) via Apple's GameController framework combined with raw HID overrides.
  * **USB (Wired):** Plug-and-play. Ensures lowest possible latency.

---

## Dual-Mode Architecture

### 1. Menu Bar Helper
On launch, DualSenseT runs as a status item in the macOS Menu Bar. 
* **Live Status:** Displays connection type and battery percentage (e.g. `[BT] 85%` or `[USB] 100%`).
* **Quick Action Presets:** Click the menu icon to switch between default presets (e.g. Bow & Arrow, Heavy Rifle, Racing Brake, Machine Gun, Semi-Auto Pistol, and more) instantly without opening the dashboard.
* **Window Controls:** Open the main configuration dashboard or quit the app cleanly.

### 2. Main Dashboard Window
A clean, premium, semi-transparent SwiftUI dashboard. You can close the main dashboard window at any time; the app continues monitoring profile triggers and running the UDP server from the menu bar.

---

## Tab-by-Tab Dashboard Guide

### 1. Left Trigger (L2) & Right Trigger (R2)
These tabs let you configure Sony's physical **Adaptive Triggers** to simulate different mechanical behaviors. DualSenseT supports **11 trigger modes** — more than any other macOS controller utility.

#### Basic Modes:
* **Off (Default):** Normal trigger pull. No added resistance or haptic feedback.
* **Feedback:** Continuous resistance from a configurable start position onward.
  * *Start Position, Strength*
* **Weapon:** Resistance zone between start and end — simulates a firearm trigger pull.
  * *Start Position, End Position, Strength*
* **Vibration:** Haptic vibration buzzing against your finger.
  * *Start Position, Amplitude, Frequency*

#### Advanced Modes:
* **Section Resistance:** Resistance only within the start-end zone — no effect outside that range.
  * *Start Position, End Position, Strength*
* **Semi-Automatic:** Resistance between start and end positions, snaps back when released past end. Simulates a semi-auto firearm.
  * *Start Position, End Position, Strength*
* **Automatic:** Continuous full-pull resistance with a repeating cycle effect.
  * *Start Position, Strength, Effect Frequency*

#### Expert Modes:
* **Slope Feedback:** Gradually increasing resistance from a start strength to an end strength across the trigger travel. Perfect for realistic brake simulation.
  * *Start Position, End Position, Start Strength, End Strength*
* **Multi-Position Feedback:** Alternating strong/weak resistance zones for a bumpy, textured resistance feel.
  * *Start Position, Strength*
* **Multi-Position Vibration:** Alternating vibration intensities for a textured vibration pattern.
  * *Start Position, Amplitude, Frequency*
* **Full Press:** Maximum resistance across the entire trigger travel. No parameters needed.

#### Visual Preview & Test Gauge:
* **Live Spring-Loaded Preview Bar:** Displays a simulated haptic bar showing trigger state, mode-specific active zones, and vibration effects with per-mode color coding.
* **Physical Pull Gauge:** A blue bar showing the real-time physical position of your finger on the controller trigger.

---

### 2. Lightbar
Allows customizing the LED lightbar wrapping around the touchpad.
* **Color Picker:** Select any color from a native picker.
* **Pulse Mode:** Enables a breathing/pulsing animation effect.
* **Presets:** Quick buttons to select signature PlayStation Blue, Neon Cyan, Neon Purple, Neon Orange, or Red.

---

### 3. Haptics
A dedicated tab for **rumble motors**, **microphone LED**, and **player indicator LEDs** — all controlled via raw HID reports.

#### Rumble Motor Test:
* **Left & Right Motor Sliders:** Independently control the intensity (0-100%) of each rumble motor.
* **Quick Actions:**
  * **Test Pulse:** Smooth ramp-up/ramp-down intensity pattern.
  * **Heartbeat:** Two quick pulses followed by a pause — mimics a heartbeat.
  * **Max Power:** Sets both motors to 100%.
  * **Stop All:** Immediately silences both motors.

#### Microphone LED:
* **Off / On / Pulse:** Controls the orange mute indicator LED next to the microphone. Useful for visual status indicators.

#### Player Indicator LEDs:
* **5-LED Toggle Grid:** Individually toggle each of the 5 indicator LEDs below the touchpad.
* **Player Presets (P1-P5):** Standard PlayStation player number patterns.
* **All Off:** Clears all indicator LEDs.

---

### 4. Live Map (Visualizer)
Provides a real-time vector schematic of the controller to diagnose inputs.
* **Button Highlights:** Pressing buttons (Cross, Circle, Square, Triangle, L1, R1, Options, Create, PS) highlights the corresponding key in blue.
* **Joysticks Tracking:** Left/Right analog sticks coordinates are drawn on active 2D grids with precise coordinate displays.
* **Touchpad coordinate mapping:** Displays the coordinates of one or two active fingers touching the controller touchpad, complete with fading pointer trails.

---

### 5. Sensors (Gyroscope & Accelerometer)
Provides 3D spatial diagnostics of the controller's motion.
* **3D Glowing Card:** A rendered 3D rectangle that rotates in real-time to match the pitch, roll, and yaw of your physical controller.
* **Attitude Quaternion:** Displays the mathematically computed quaternion coordinates (`w`, `x`, `y`, `z`) in real-time.
* **Recenter Sensors:** Click this button (or wait for the 0.3-second auto-align) to set the controller's current orientation as the "flat" reference point.

---

### 6. UDP Server
Emulates the **DualSenseX UDP Server protocol** on port `6969`.
* **Purpose:** Allows games running inside Wine, CrossOver, Game Porting Toolkit, or native game mods (e.g. Cyberpunk 2077, Spider-Man) to send JSON instructions directly to your controller triggers and LEDs.
* **Extended Protocol:** Maps all 19 DSX trigger types (Normal, Custom, GameCube, Resistance, Bow, Galloping, SemiAutomaticGun, AutomaticGun, Machine, Choppy, VerySoft through Hardest, Rigid, VibrateTriggerPulse, VibrateTrigger) to the closest native DualSenseT trigger mode for maximum fidelity.
* **Configuration:** Toggle active server status and configure the server to launch automatically on app startup.

---

### 7. Presets
Manage custom profiles.
* **13 Default Presets:** Including *Bow & Arrow*, *Heavy Rifle*, *Racing Brake*, *Soft Click*, *Galloping*, *Machine Gun*, *Heavy Spring*, *Semi-Auto Pistol*, *Automatic Rifle*, *Bumpy Road*, *Slope Brake*, and *Off*.
* **Save Current Preset:** Save your active L2/R2 trigger settings, LED color, and haptic pulsing configurations into a named preset.
* **Custom Presets:** List, apply, or delete your custom saved presets. Presets are saved locally as standard JSON files with backward-compatible loading.

---

### 8. Settings
Advanced remapping and background automation.

#### Per-App Profiles:
* Assign a trigger preset to a specific application or game (e.g., Steam games, Crossover, Céleste).
* The app runs a lightweight background observer that automatically swaps controller configurations when the assigned game window is focused.

#### Touchpad Gesture Remapping:
* Map swipe directions (Up, Down, Left, Right) to keypress simulations.
* Supports mapping gestures to Spacebar, Left Arrow, Right Arrow, Up Arrow, and Down Arrow at the virtual HID level.

---

## Advanced Engineering Features

### Adaptive IMU Complementary Filter
The macOS `GameController` framework does not natively populate the `attitude` quaternion (returns static `w:1, x:0, y:0, z:0`) for the DualSense controller. To solve this, DualSenseT implements an **Adaptive Complementary Filter** that fuses raw sensor data in real-time:
1. **Gyroscope Integration:** Integrates the rotation rates around the X (pitch), Y (yaw), and Z (roll) axes.
2. **Accelerometer Drift Correction:** Uses the gravity vector from the accelerometer to correct pitch and roll drift.
3. **Adaptive Gain Coupling:** 
   * When in fast motion, the accelerometer correction is bypassed to avoid centripetal force corruption.
   * When stationary, the filter gain increases ($k_{acc} = 0.1$) to quickly align the controller flat to gravity.
4. **Resting Auto-Decay:** When resting still, the integrated yaw (which has no absolute compass reference) decays slowly back to $0.0$, eliminating yaw drift.

### Zero-CPU Idle Optimization
To prevent main thread UI flooding and high CPU utilization from high-frequency controller vibration notifications (which fire at 150Hz+), the app:
* Dynamically disables motion sensors (`sensorsActive = false`) when the dashboard is closed, minimized, or switched away from the Sensors tab.
* Bypasses main-thread dispatches for stick and button updates when the window is hidden.
* Reduces idle CPU usage to **0.0%**.

### Raw HID Background Override
The macOS `GameController` framework ceases sending output reports to controllers when the host application loses window focus. To keep adaptive triggers active when you click away to play a game, DualSenseT implements a multi-layered persistence system:

1. **Dual Focus Detection:** Monitors both `NSApplication.didResignActiveNotification` and `NSWorkspace.didActivateApplicationNotification` to reliably detect focus loss — even for apps running in `.accessory` mode without a Dock icon.
2. **Exponential Backoff Burst:** On focus loss, immediately fires 8 HID reports at 0/30/60/100/200/500/1000/2000ms intervals to win the race against macOS and GameController framework resets.
3. **Adaptive Background Timer:** Starts at 50ms polling for the first 3 seconds (critical window), then settles to 500ms for sustained background operation.
4. **Stale Device Recovery:** If an HID write fails, automatically clears the cached device handle, resets the Bluetooth sequence number, and retries with a freshly discovered device.
5. **Reconnection Resilience:** On controller reconnect, invalidates the cached HID device to force fresh discovery, preventing stale handle issues.

---

## Compilation & Unit Testing

The repository contains a simple, zero-dependency packaging structure and build pipeline.

### Build and Package:
Run the build script to compile `main.swift` and generate `DualSenseT.app`:
```bash
./build.sh
```

### Run Unit Tests:
Run the build script with the `test` argument to compile and execute the custom unit test harness (`tests.swift`):
```bash
./build.sh test
```
The test suite validates preset serialization, parameter parsing, touchpad remapping thresholds, quaternion calculations, HID report construction, background transition behavior, and end-to-end scenario tests.
