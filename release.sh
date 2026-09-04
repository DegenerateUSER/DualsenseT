#!/bin/bash
set -euo pipefail

VERSION="${1:-${VERSION:-}}"
APP_NAME="Sticky Fingers"
APP_BUNDLE="${APP_NAME}.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN="${NOTARY_KEYCHAIN:-}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: ./release.sh <semantic-version>"
    exit 1
fi

if [ -z "${CODESIGN_IDENTITY}" ]; then
    echo "CODESIGN_IDENTITY must name a Developer ID Application certificate."
    exit 1
fi

if [ -z "${NOTARY_PROFILE}" ]; then
    echo "NOTARY_PROFILE must name credentials stored with xcrun notarytool."
    exit 1
fi

if [[ "${CODESIGN_IDENTITY}" != *"Developer ID Application"* ]]; then
    echo "Refusing release: CODESIGN_IDENTITY is not a Developer ID Application identity."
    exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

echo "Running tests..."
./build.sh test

echo "Building signed ${APP_NAME} ${VERSION}..."
VERSION="${VERSION}" \
BUILD_NUMBER="${BUILD_NUMBER:-1}" \
CODESIGN_IDENTITY="${CODESIGN_IDENTITY}" \
./build.sh

codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT
SUBMISSION_ZIP="${TEMP_DIR}/Sticky-Fingers-${VERSION}-notarization.zip"
ditto -c -k --keepParent "${APP_BUNDLE}" "${SUBMISSION_ZIP}"

echo "Submitting to Apple notarization..."
NOTARY_OPTIONS=(--keychain-profile "${NOTARY_PROFILE}")
if [ -n "${NOTARY_KEYCHAIN}" ]; then
    NOTARY_OPTIONS+=(--keychain "${NOTARY_KEYCHAIN}")
fi
xcrun notarytool submit "${SUBMISSION_ZIP}" "${NOTARY_OPTIONS[@]}" --wait

xcrun stapler staple "${APP_BUNDLE}"
xcrun stapler validate "${APP_BUNDLE}"
spctl --assess --type execute --verbose=2 "${APP_BUNDLE}"

mkdir -p release
ARCHIVE="Sticky-Fingers-${VERSION}-macOS-arm64.zip"
rm -f "release/${ARCHIVE}" "release/${ARCHIVE}.sha256"
ditto -c -k --keepParent "${APP_BUNDLE}" "release/${ARCHIVE}"
(
    cd release
    shasum -a 256 "${ARCHIVE}" > "${ARCHIVE}.sha256"
)

echo "Release artifacts:"
echo "  release/${ARCHIVE}"
echo "  release/${ARCHIVE}.sha256"

