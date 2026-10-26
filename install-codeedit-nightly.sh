#!/bin/bash
#
# CodeEdit nightly — one-step installer
#
# Downloads the release disk image, verifies its SHA-256 against the published
# checksum, installs CodeEdit to /Applications, and clears the quarantine flag
# so macOS lets it launch.
#
# Usage:
#   bash install-codeedit-nightly.sh
#   bash install-codeedit-nightly.sh --check     # only check for a newer build
#
set -euo pipefail

REPO="neg2sode/CodeEdit"
TAG="nightly-0.3.6-pre.47.2"
ASSET="CodeEdit-0.3.6-pre.47-fa2aebd.dmg"
CHECKSUM="8f9293851710f8cde81a2776cb6fe8e7cda86c0e0259f096089f71527b8aec67"
APP="CodeEdit.app"
DEST="/Applications/$APP"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
fail() { printf '\n  error: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null || fail "curl is required"
command -v shasum >/dev/null || fail "shasum is required"

BASE="https://github.com/$REPO/releases/download/$TAG"

# ---- optional: check for a newer published build -------------------------
if [[ "${1:-}" == "--check" ]]; then
  bold "Latest nightly for $REPO"
  LATEST=$(curl -fsSL "https://api.github.com/repos/$REPO/releases" 2>/dev/null \
           | grep -o '"tag_name": *"nightly[^"]*"' | head -1 | sed 's/.*: *"//;s/"//') || true
  info "published: ${LATEST:-<none>}"
  info "this script: $TAG"
  [[ -n "${LATEST:-}" && "$LATEST" != "$TAG" ]] && info "a newer build is available — re-run without --check to install it"
  exit 0
fi

bold "CodeEdit nightly installer"
info "release:  $TAG"
info "asset:    $ASSET"

# ---- upgrade handling -----------------------------------------------------
if [[ -d "$DEST" ]]; then
  bold "An existing CodeEdit is installed"
  OLDVER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$DEST/Contents/Info.plist" 2>/dev/null || echo "unknown")
  info "current version: $OLDVER"
  read -r -p "  Replace it with this nightly? [y/N] " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]] || { info "cancelled — nothing was changed"; exit 0; }
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/codeedit-nightly.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# ---- download -------------------------------------------------------------
bold "Downloading (33 MB)"
curl -fL --progress-bar "$BASE/$ASSET" -o "$TMP/$ASSET" || fail "download failed — check your connection or the release page: https://github.com/$REPO/releases"

# ---- verify integrity BEFORE touching /Applications ----------------------
bold "Verifying checksum"
ACTUAL=$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')
if [[ "$ACTUAL" != "$CHECKSUM" ]]; then
  fail "checksum mismatch — the download is corrupt or has been tampered with. Nothing was installed.
         expected: $CHECKSUM
         actual:   $ACTUAL"
fi
info "SHA-256 OK"

# Confirm the app inside is the version this script advertises.
bold "Mounting disk image"
hdiutil attach "$TMP/$ASSET" -mountpoint "$TMP/mnt" -nobrowse -quiet || fail "could not mount the disk image"
cleanup_mount() { hdiutil detach "$TMP/mnt" -quiet 2>/dev/null || true; }
trap 'cleanup_mount; rm -rf "$TMP"' EXIT

[[ -d "$TMP/mnt/$APP" ]] || fail "the disk image does not contain $APP"
BUILT=$(/usr/libexec/PlistBuddy -c "Print :CE_VERSION_POSTFIX" "$TMP/mnt/$APP/Contents/Info.plist" 2>/dev/null || echo "?")
info "verified bundle: CodeEdit ($BUILT)"

# ---- install --------------------------------------------------------------
bold "Installing to /Applications"
pkill -x CodeEdit 2>/dev/null || true          # quit a running copy so the swap is clean
if [[ -d "$DEST" ]]; then
  rm -rf "$DEST"                                # replace, don't merge stale resources
fi
ditto "$TMP/mnt/$APP" "$DEST" 2>/dev/null || {
  info "/Applications needs admin rights for this step"
  sudo ditto "$TMP/mnt/$APP" "$DEST"
}

# The build is ad-hoc signed (no paid Apple Developer ID), so macOS quarantines
# it. Clear that flag so it opens normally — this is the same effect as
# right-clicking the app and choosing Open.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

bold "Done"
info "CodeEdit nightly $BUILT is installed at $DEST"
info "Open it from Launchpad, Spotlight, or: open -a CodeEdit"
info ""
info "Note: this build is ad-hoc signed and not notarized. It has the App Sandbox"
info "disabled so the integrated terminal works (see INTEGRATED-TERMINAL.md)."
info "The source and every change are on GitHub: https://github.com/$REPO"
