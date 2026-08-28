# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | ✅ |

## Reporting a Vulnerability

If you discover a security vulnerability, **please do not open a public issue**.

Instead, email directly (or open a [private GitHub security advisory](https://github.com/DegenerateUSER/DualsenseT/security/advisories/new)) with:
- A description of the vulnerability
- Steps to reproduce
- Potential impact

You'll receive a response within 72 hours. Valid reports will be credited in the fix's release notes.

## Notes on IOKit & HID Access

DualSenseT uses raw IOKit HID writes to maintain adaptive trigger state in the background. This is intentional and operates entirely on the local machine against a paired controller device. No network data is sent (except via the opt-in UDP server on localhost port 6969).
