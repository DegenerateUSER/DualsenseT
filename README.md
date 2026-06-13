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
   * [Live Map (Visualizer)](#3-live-map-visualizer)
   * [Sensors (Gyroscope & Accelerometer)](#4-sensors-gyroscope--accelerometer)
   * [UDP Server](#5-udp-server)
   * [Presets](#6-presets)
   * [Settings (Touchpad Gestures & Profiles)](#7-settings)
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
  * **Bluetooth (Wireless):** Supported for all features (Adaptive Triggers, LED Lightbar, Touchpad, Gyro/Accel) via Apple's GameController framework combined with raw HID overrides.
  * **USB (Wired):** Plugs in plug-and-play. Ensures lowest possible latency.

---

## Dual-Mode Architecture

### 1. Menu Bar Helper
On launch, DualSenseT runs as a status item in the macOS Menu Bar. 
* **Live Status:** Displays connection type and battery percentage (e.g. `[BT] 85%` or `[USB] 100%`).
* **Quick Action Presets:** Click the menu icon to switch between default presets (e.g. Bow & Arrow, Heavy Rifle, Racing Brake) instantly without opening the dashboard.
* **Window Controls:** Open the main configuration dashboard or quit the app cleanly.

### 2. Main Dashboard Window
A clean, premium, semi-transparent SwiftUI dashboard. You can close the main dashboard window at any time; the app continues monitoring profile triggers and running the UDP server from the menu bar.

---

## Tab-by-Tab Dashboard Guide

### 1. Left Trigger (L2) & Right Trigger (R2)
These tabs let you configure Sony's physical **Adaptive Triggers** to simulate different mechanical behaviors.

#### Mode Definitions:
* **Off (Default):** Normal trigger pull. No added resistance or haptic feedback.
* **Feedback:** Simulates pulling against a stiff spring. 
  * **Start Position (0.0 - 1.0):** The physical pull distance where the resistance begins.
  * **Strength (0.0 - 1.0):** The stiffness of the simulated spring force.
* **Weapon:** Simulates the trigger of a firearm (resistance builds up to a gate, then snaps).
  * **Start Position (0.0 - 1.0):** The pull distance where resistance begins.
  * **End Position (0.0 - 1.0):** The trigger breakthrough threshold.
  * **Strength (0.0 - 1.0):** Force needed to "break through" the threshold.
* **Vibration:** Simulates a haptic vibration buzzing against your finger.
  * **Start Position (0.0 - 1.0):** The pull distance where vibration starts.
  * **Amplitude (0.0 - 1.0):** The strength of the vibration buzz.
  * **Frequency (0.0 - 1.0):** Speed of haptic pulses (cycles per second).

#### Visual Preview & Test Gauge:
* **Live Spring-Loaded Preview Bar:** Displays a simulated haptic bar showing trigger state, weapon snap thresholds, and active vibrations.
* **Physical Pull Gauge:** A blue bar showing the real-time physical position of your finger on the controller trigger.

---

### 2. Lightbar
Allows customizing the LED lightbar wrapping around the touchpad.
* **Color Picker:** Select any color from a native picker.
* **Pulse Mode:** Enables a breathing/pulsing animation effect.
* **Presets:** Quick buttons to select signature PlayStation Blue, Neon Cyan, Neon Purple, Neon Orange, or Red.

---

### 3. Live Map (Visualizer)
Provides a real-time vector schematic of the controller to diagnose inputs.
* **Button Highlights:** Pressing buttons (Cross, Circle, Square, Triangle, L1, R1, Options, Create, PS) highlights the corresponding key in blue.
* **Joysticks Tracking:** Left/Right analog sticks coordinates are drawn on active 2D grids with precise coordinate displays.
* **Touchpad coordinate mapping:** Displays the coordinates of one or two active fingers touching the controller touchpad, complete with fading pointer trails.

---

### 4. Sensors (Gyroscope & Accelerometer)
Provides 3D spatial diagnostics of the controller's motion.
* **3D Glowing Card:** A rendered 3D rectangle that rotates in real-time to match the pitch, roll, and yaw of your physical controller.
* **Attitude Quaternion:** Displays the mathematically computed quaternion coordinates (`w`, `x`, `y`, `z`) in real-time.
* **Recenter Sensors:** Click this button (or wait for the 0.3-second auto-align) to set the controller's current orientation as the "flat" reference point.

---

### 5. UDP Server
Emulates the **DualSenseX UDP Server protocol** on port `6969`.
* **Purpose:** Allows games running inside Wine, CrossOver, Game Porting Toolkit, or native game mods (e.g. Cyberpunk 2077, Spider-Man) to send JSON instructions directly to your controller triggers and LEDs.
* **Configuration:** Toggle active server status and configure the server to launch automatically on app startup.

---

### 6. Presets
Manage custom profiles.
* **Save Current Preset:** Save your active L2/R2 trigger settings, LED color, and haptic pulsing configurations into a named preset.
* **Default Presets:** Access predefined configurations like *Bow & Arrow*, *Heavy Rifle*, and *Racing Brake*.
* **Custom Presets:** List, apply, or delete your custom saved presets. Presets are saved locally as standard JSON files.

---

### 7. Settings
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
The macOS `GameController` framework ceases sending output reports to controllers when the host application loses window focus. To keep adaptive triggers active when you click away to play a game, DualSenseT:
1. Detects focus loss (`didResignActiveNotification`).
2. Discovers the underlying controller's raw `IOHIDDevice` profile.
3. Computes the required DualSense Bluetooth output report frame, packages the custom settings, signs the report with a **Bluetooth CRC32 checksum**, and writes it directly to the controller via raw IOKit USB/Bluetooth output channels.

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
The test suite validates preset serialization, parameter parsing, touchpad remapping thresholds, and quaternion calculations.
