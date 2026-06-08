#!/usr/bin/env bash
# update-bindings.sh — Download the latest zkID release artifacts and patch
# Package.swift, Sources/COpenACFFI/include/openac_mobile_appFFI.h, and
# Sources/mopro.swift in place.
#
# WHY versioned URLs: SPM caches binary artifacts keyed by URL. The "latest"
# alias never changes, so SPM always serves the cached old zip and the checksum
# mismatches. Writing the actual versioned URL (e.g. /download/v1.2.3/...) into
# Package.swift changes the cache key on every release and forces a fresh fetch.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="privacy-ethereum/zkID"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ZIP_PATH="$WORK_DIR/MoproBindings.xcframework.zip"

LATEST_TAG="RSA-X.509-Cert-latest"
echo "==> Using release tag: $LATEST_TAG"

XCFRAMEWORK_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/MoproBindings.xcframework.zip"
MOPRO_SWIFT_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/mopro.swift"

# ── Clear SPM cache to force a fresh fetch ───────────────────────────────────
echo "==> Clearing SPM cache"
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build
rm -rf .swiftpm
echo "    done."

# ── Download the xcframework zip ──────────────────────────────────────────────
echo "==> Downloading $XCFRAMEWORK_URL"
curl -fSL --retry 3 -o "$ZIP_PATH" "$XCFRAMEWORK_URL"

# ── Compute checksum ──────────────────────────────────────────────────────────
echo "==> Computing checksum"
CHECKSUM=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "    checksum: $CHECKSUM"

# ── Patch Package.swift ───────────────────────────────────────────────────────
PACKAGE_SWIFT="$REPO_ROOT/Package.swift"
echo "==> Patching $PACKAGE_SWIFT"

# Replace the binaryTarget url with the versioned URL
sed -i '' \
    "s|url: \"[^\"]*MoproBindings\.xcframework\.zip\"|url: \"$XCFRAMEWORK_URL\"|g" \
    "$PACKAGE_SWIFT"

# Replace the checksum line (any hex string of 64 chars)
sed -i '' \
    "s|checksum: \"[0-9a-f]\{64\}\"|checksum: \"$CHECKSUM\"|g" \
    "$PACKAGE_SWIFT"

echo "    done."

# ── Unzip and extract the FFI header ─────────────────────────────────────────
echo "==> Unzipping xcframework"
unzip -q "$ZIP_PATH" -d "$WORK_DIR"

HEADER_SRC="$WORK_DIR/MoproBindings.xcframework/ios-arm64/Headers/openac_mobile_app/openac_mobile_appFFI.h"
HEADER_DST="$REPO_ROOT/Sources/COpenACFFI/include/openac_mobile_appFFI.h"

if [[ ! -f "$HEADER_SRC" ]]; then
    echo "ERROR: header not found at expected path inside zip:" >&2
    echo "  $HEADER_SRC" >&2
    echo "Contents of xcframework:" >&2
    find "$WORK_DIR/MoproBindings.xcframework" -name "*.h" >&2
    exit 1
fi

echo "==> Updating $HEADER_DST"
cp "$HEADER_SRC" "$HEADER_DST"
echo "    done."

# ── Download mopro.swift ──────────────────────────────────────────────────────
MOPRO_SWIFT_DST="$REPO_ROOT/Sources/mopro.swift"
echo "==> Downloading $MOPRO_SWIFT_URL -> $MOPRO_SWIFT_DST"
curl -fSL --retry 3 -o "$MOPRO_SWIFT_DST" "$MOPRO_SWIFT_URL"
echo "    done."

echo ""
echo "All done. Summary:"
echo "  tag      : $LATEST_TAG"
echo "  url      : $XCFRAMEWORK_URL"
echo "  checksum : $CHECKSUM"
echo "  Package.swift patched"
echo "  $HEADER_DST updated"
echo "  $MOPRO_SWIFT_DST updated"
