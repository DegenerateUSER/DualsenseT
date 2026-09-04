# Security Policy

## Supported Version

Security fixes are provided on the latest release and the current `main` branch.

## Report a Vulnerability Privately

Do not open a public issue for a vulnerability.

Use GitHub's
[private vulnerability reporting](https://github.com/DegenerateUSER/DualsenseT/security/advisories/new)
and include:

- A concise description and affected version or commit
- Reproduction steps or a proof of concept
- Expected impact
- Suggested mitigation, if known
- Whether disclosure is time-sensitive

Reports are acknowledged and handled on a best-effort basis. Please allow time to reproduce,
fix, test on hardware, and publish a signed release before public disclosure.

## Security Boundaries

Sticky Fingers:

- Uses raw HID access to communicate with a locally connected controller.
- Captures system audio only after explicit user action and macOS permission.
- Processes audio in memory and does not record or upload it.
- Rejects non-loopback peers on the optional UDP control server.
- Stores presets and logs in the current user's Application Support directory.
- Does not include analytics, a cloud backend, or an automatic update client.

The UDP protocol is unauthenticated because it is intended for same-Mac game/mod
integration. Treat any change that allows non-loopback access as security-sensitive.

## In Scope

- Remote or local command injection
- Unsafe parsing of UDP input
- Memory-safety issues in vendored HIDAPI integration
- Permission bypass or unexpected capture
- Sensitive data written to logs
- Release-signing or update-channel compromise
- Path traversal or unsafe preset handling

## Out of Scope

- Bugs requiring physical modification of a controller
- Vulnerabilities in macOS or controller firmware without an app-level mitigation
- Denial of service from a trusted local process already able to control the user's session
- Social engineering unrelated to an official release artifact

## Release Authenticity

Official binaries are intended to be Developer ID signed, hardened-runtime enabled, and
notarized by Apple. Release notes should publish a SHA-256 checksum. Users can verify:

```bash
codesign --verify --deep --strict --verbose=2 "Sticky Fingers.app"
spctl --assess --type execute --verbose=2 "Sticky Fingers.app"
shasum -a 256 Sticky-Fingers-*.zip
```

