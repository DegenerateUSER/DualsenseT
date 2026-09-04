# Troubleshooting

Start with the latest release, quit other controller-configuration tools, and test with one
controller connected. Two apps sending HID reports can continuously overwrite each other.

## Controller Is Not Detected

### USB

- Use a data-capable USB cable; charge-only cables do not expose HID or audio.
- Connect directly to the Mac before testing a hub.
- Press the PS button once after connecting.
- Quit and reopen Sticky Fingers.

### Bluetooth

1. Hold **Create + PS** until the lightbar flashes rapidly.
2. Pair **DualSense Wireless Controller** in macOS Bluetooth settings.
3. Disconnect USB while testing Bluetooth so the active transport is unambiguous.

## Triggers, Lighting, or Rumble Do Not Respond

- Quit Steam Input, controller mappers, and other DualSense utilities temporarily.
- Confirm the sidebar reports the expected USB or Bluetooth connection.
- Set both trigger modes to Off, then apply one simple Feedback mode.
- Stop Audio Haptics before diagnosing classic rumble. Audio haptics intentionally hands the
  actuators to the USB PCM stream while it is active.
- Disconnect and reconnect the controller if another app previously owned its LED state.

## The Audio Page Cannot Find the Controller

Controller audio is **USB only**. Bluetooth can carry controller HID reports but does not
expose the DualSense speaker, microphone, headset jack, or haptic audio channels to macOS.

If USB is connected:

- Try another data-capable cable or port.
- Open Audio MIDI Setup and confirm **DualSense Wireless Controller** appears.
- Click Refresh in the Audio page.
- Reopen Sticky Fingers after connecting the controller.

## Audio Haptics Will Not Start

1. Confirm the Audio page says Ready.
2. Configure Quadraphonic if prompted.
3. Allow Sticky Fingers under:
   `System Settings → Privacy & Security → Screen & System Audio Recording`.
4. Quit and reopen the app.
5. Start audible media, then start Audio Haptics.

If a locally built copy was rebuilt, macOS may see its ad-hoc signature as a new app. Reset
the stale permission and grant it again:

```bash
tccutil reset ScreenCapture com.degenerateuser.stickyfingers
```

Stable Developer ID or Apple Development signing prevents most permission churn.

## The Response Meter Moves but the Controller Does Not Vibrate

- Open **Advanced Diagnostics** on the Audio page.
- Run Haptic L and Haptic R separately while holding the controller.
- Confirm the channel layout is Quadraphonic:
  `Front L, Front R, Surround L, Surround R`.
- Stop other apps that may be sending rumble reports.
- Disconnect/reconnect USB and retry.

## Audio Haptics Stop After Switching Tabs

Audio haptics are app-wide and should continue while configuring triggers or using another
application. If they stop:

1. Return to Audio and check the status.
2. Stop and restart Audio Haptics once.
3. Record the macOS version, stream counters from Advanced Diagnostics, and the app log.
4. File a bug report.

## High CPU Usage

The app processes high-rate HID and motion samples, but UI delivery is capped and hidden
windows pause visual updates. Audio haptics necessarily performs real-time system-audio
capture and DSP.

- Compare CPU with Audio Haptics stopped.
- Close or minimize the dashboard while playing.
- Disable Sensors or Live Map visibility when not needed.
- Report sustained idle CPU with the exact macOS version and connection type.

## Window Is Closed but the App Is Still Running

This is expected: background trigger profiles, audio haptics, and the UDP server can continue
after the main window closes. Reopen from the Dock or menu-bar controller icon. Quit fully
with `⌘Q` or **Quit Sticky Fingers**.

## Logs and Bug Reports

The app log is stored at:

```text
~/Library/Application Support/Sticky Fingers/sticky-fingers.log
```

Before sharing it, inspect it for application names or device details you consider private.
Attach only the relevant section to the
[bug report](https://github.com/DegenerateUSER/DualsenseT/issues/new?template=bug_report.yml).
Include:

- macOS and Mac model
- Controller model and firmware when known
- USB or Bluetooth
- Sticky Fingers version
- Exact reproduction steps
- Whether other controller tools were running

