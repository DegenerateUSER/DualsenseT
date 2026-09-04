# Third-Party Notices

Sticky Fingers includes source from third-party projects. Their copyright and license terms
remain with their respective owners.

## HIDAPI

- Project: [libusb/hidapi](https://github.com/libusb/hidapi)
- Vendored location: `Sources/CHidapi/`
- Version lineage: HIDAPI 0.14 macOS backend
- Copyright: Alan Ott, Signal 11 Software, and the libusb/hidapi contributors

HIDAPI offers a choice of GNU GPL v3, BSD-style, or its original permissive license. Sticky
Fingers uses the vendored HIDAPI files under **GNU GPL version 3 only**, matching this
project's license.

The source files retain HIDAPI's original copyright and multi-license notices. The upstream
license index is available at:

<https://github.com/libusb/hidapi/blob/master/LICENSE.txt>

## Apple Frameworks

Sticky Fingers links against public frameworks supplied by macOS, including AppKit, SwiftUI,
GameController, IOKit, CoreAudio, AudioToolbox, AVFAudio, ScreenCaptureKit, CoreMedia,
CoreHaptics, and Network. These system frameworks are not distributed by this repository and
remain subject to Apple's terms.

