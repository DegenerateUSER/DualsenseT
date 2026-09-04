# Release Guide

Sticky Fingers releases are distributed through GitHub as an Apple silicon macOS
application. Public artifacts must be Developer ID signed, hardened-runtime enabled,
notarized, stapled, checksummed, and built from the matching public tag.

Ad-hoc builds are for local development only.

## Prerequisites

- Active Apple Developer Program membership
- `Developer ID Application` certificate
- Xcode Command Line Tools
- Notary service credentials
- Clean checkout of the commit being released
- All hardware gates in [`LAUNCH_CHECKLIST.md`](LAUNCH_CHECKLIST.md) completed or clearly
  disclosed

## Local Release

Store notarization credentials in the login keychain:

```bash
xcrun notarytool store-credentials "sticky-fingers-notary" \
  --apple-id "APPLE_ID" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

List signing identities:

```bash
security find-identity -v -p codesigning
```

Build, test, sign, notarize, staple, and package:

```bash
CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
NOTARY_PROFILE="sticky-fingers-notary" \
./release.sh 1.0.0
```

The script produces:

```text
release/Sticky-Fingers-1.0.0-macOS-arm64.zip
release/Sticky-Fingers-1.0.0-macOS-arm64.zip.sha256
```

Verify the archive on a second Mac or a clean user account before publishing.

## GitHub Release Workflow

The tag-triggered workflow requires these repository secrets:

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `KEYCHAIN_PASSWORD`

Create the certificate secret:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Never commit the `.p12`, app-specific password, API key, or temporary keychain.

To publish:

1. Update `CHANGELOG.md`.
2. Confirm `./build.sh test` reports zero failures.
3. Complete the manual hardware matrix.
4. Commit all release changes.
5. Create and push a signed tag:

   ```bash
   git tag -s v1.0.0 -m "Sticky Fingers 1.0.0"
   git push origin v1.0.0
   ```

6. Watch the Release workflow.
7. Download the published archive and verify Gatekeeper, signature, staple, checksum, and
   first-run permissions.
8. Publish launch material only after the release asset passes that clean-install test.

## Versioning

- Patch: compatible fixes and documentation
- Minor: backward-compatible features
- Major: incompatible preset, UDP, protocol, or platform-support changes

`VERSION` becomes `CFBundleShortVersionString`; `BUILD_NUMBER` becomes `CFBundleVersion`.

## GPL Distribution Requirements

A binary release must provide the corresponding source under GPL-3.0-only. Publishing the exact
tag in the same GitHub release satisfies the intended source-access path. Keep:

- `LICENSE`
- `THIRD_PARTY_NOTICES.md`
- Complete build scripts
- Vendored HIDAPI source and notices

The app bundle also includes the license and third-party notice in `Contents/Resources`.

## Release Notes Template

```markdown
## Sticky Fingers 1.0.0

### Highlights
- ...

### Fixes
- ...

### Compatibility
- macOS 14+
- Apple silicon
- DualSense: USB and Bluetooth
- Controller audio/audio haptics: USB only

### Known limitations
- ...

### Verification
- 75 automated tests passed
- Hardware matrix: ...

### Install
Download the macOS arm64 zip, move Sticky Fingers.app to Applications, and open it.
```

