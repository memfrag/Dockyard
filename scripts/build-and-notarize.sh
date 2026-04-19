#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Dockyard: archive, notarize, DMG, sign for Sparkle, publish GitHub release,
# and update appcast.xml.
#
# Prerequisites:
#   - xcrun notarytool store-credentials 'notary' (one-time setup)
#   - gh auth login
#   - Sparkle EdDSA keys in keychain (run: ./Sparkle-tools/bin/generate_keys)
#
# Usage:
#   ./scripts/build-and-notarize.sh
# -----------------------------------------------------------------------------

# --- Constants ---------------------------------------------------------------

SCHEME="Dockyard (Release)"
APP_NAME="Dockyard"
BUNDLE_ID="io.apparata.Dockyard"
GITHUB_REPO="memfrag/Dockyard"
KEYCHAIN_PROFILE="notary"
SPARKLE_VERSION="2.9.0"

# --- Paths -------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SPARKLE_TOOLS_DIR="$PROJECT_DIR/Sparkle-tools"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"
INFO_PLIST="$PROJECT_DIR/Dockyard/macOS/Info.plist"

# --- Helpers -----------------------------------------------------------------

error() {
    echo "ERROR: $*" >&2
    exit 1
}

show_log_tail() {
    local log="$1"
    if [ -f "$log" ]; then
        echo "--- Last 30 lines of $log ---" >&2
        tail -30 "$log" >&2
        echo "------------------------------" >&2
    fi
}

confirm_newer_version() {
    local current="$1"
    local proposed="$2"
    # Returns 0 if proposed > current using sort -V
    if [ "$(printf '%s\n%s\n' "$current" "$proposed" | sort -V | tail -1)" = "$proposed" ] && [ "$current" != "$proposed" ]; then
        return 0
    fi
    return 1
}

# --- Pre-flight checks -------------------------------------------------------

command -v xcodebuild >/dev/null || error "xcodebuild not found"
command -v gh >/dev/null || error "gh CLI not found. Install: brew install gh"
command -v hdiutil >/dev/null || error "hdiutil not found"
[ -f "$EXPORT_OPTIONS" ] || error "Missing $EXPORT_OPTIONS"

# --- Clean build dir ---------------------------------------------------------

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Fetch Sparkle tools (persisted across runs) ----------------------------

if [ ! -x "$SPARKLE_TOOLS_DIR/bin/sign_update" ]; then
    echo "Downloading Sparkle $SPARKLE_VERSION tools..."
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$BUILD_DIR/Sparkle.tar.xz" \
        || error "Failed to download Sparkle tools"
    mkdir -p "$SPARKLE_TOOLS_DIR"
    tar -xf "$BUILD_DIR/Sparkle.tar.xz" -C "$SPARKLE_TOOLS_DIR" \
        || error "Failed to extract Sparkle tools"
    rm "$BUILD_DIR/Sparkle.tar.xz"
fi
[ -x "$SPARKLE_TOOLS_DIR/bin/sign_update" ] || error "sign_update not found after extraction"
[ -x "$SPARKLE_TOOLS_DIR/bin/generate_appcast" ] || error "generate_appcast not found after extraction"

# --- Version check and update -----------------------------------------------

CURRENT_VERSION=""
# Try pbxproj first
PBX_PROJECT="$PROJECT_DIR/$APP_NAME.xcodeproj/project.pbxproj"
MV_FROM_PBX=$(grep "MARKETING_VERSION = " "$PBX_PROJECT" | head -1 | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' "' || true)
if [ -n "$MV_FROM_PBX" ]; then
    CURRENT_VERSION="$MV_FROM_PBX"
fi
# Fall back to Info.plist if pbxproj has no MARKETING_VERSION
if [ -z "$CURRENT_VERSION" ] && [ -f "$INFO_PLIST" ]; then
    CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
fi
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi
echo "Current project version: $CURRENT_VERSION"

LATEST_TAG=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || true)
if [ -n "$LATEST_TAG" ]; then
    echo "Latest released version on GitHub: $LATEST_TAG"
else
    echo "No prior GitHub release found."
fi

NEEDS_BUMP=false
if [ -n "$LATEST_TAG" ]; then
    if [ "$CURRENT_VERSION" = "$LATEST_TAG" ]; then
        NEEDS_BUMP=true
    fi
fi

if [ "$NEEDS_BUMP" = "true" ]; then
    echo ""
    echo "The current version matches the latest GitHub release."
    while true; do
        read -r -p "Enter the new version (e.g. 1.2.3): " NEW_VERSION
        [ -n "$NEW_VERSION" ] || { echo "Version cannot be empty."; continue; }
        if confirm_newer_version "$CURRENT_VERSION" "$NEW_VERSION"; then
            break
        else
            echo "'$NEW_VERSION' is not strictly newer than '$CURRENT_VERSION'. Try again."
        fi
    done

    # Update pbxproj if MARKETING_VERSION / CURRENT_PROJECT_VERSION already exist there
    if grep -q "MARKETING_VERSION = " "$PBX_PROJECT"; then
        sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBX_PROJECT" \
            || error "Failed to update MARKETING_VERSION in project.pbxproj"
    fi
    if grep -q "CURRENT_PROJECT_VERSION = " "$PBX_PROJECT"; then
        sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $NEW_VERSION;/g" "$PBX_PROJECT" \
            || error "Failed to update CURRENT_PROJECT_VERSION in project.pbxproj"
    fi

    # Always update Info.plist
    [ -f "$INFO_PLIST" ] || error "Info.plist not found at $INFO_PLIST. Create it first (see skill docs)."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$INFO_PLIST" \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $NEW_VERSION" "$INFO_PLIST" \
        || error "Failed to set CFBundleShortVersionString"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_VERSION" "$INFO_PLIST" \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $NEW_VERSION" "$INFO_PLIST" \
        || error "Failed to set CFBundleVersion"

    # Commit and push
    cd "$PROJECT_DIR"
    git add "$PBX_PROJECT" "$INFO_PLIST"
    git commit -m "Bump version to $NEW_VERSION" || error "git commit failed"
    git push origin HEAD || error "git push failed"

    VERSION="$NEW_VERSION"
else
    VERSION="$CURRENT_VERSION"
fi

echo "Building version $VERSION"

# --- Archive -----------------------------------------------------------------

echo "Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    -arch arm64 \
    ENABLE_HARDENED_RUNTIME=YES \
    2>&1 | tee "$BUILD_DIR/archive.log" | tail -5 \
    || { show_log_tail "$BUILD_DIR/archive.log"; error "xcodebuild archive failed"; }

[ -d "$ARCHIVE_PATH" ] || { show_log_tail "$BUILD_DIR/archive.log"; error "Archive not found at $ARCHIVE_PATH"; }

# --- Export ------------------------------------------------------------------

echo "Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    2>&1 | tee "$BUILD_DIR/export.log" | tail -5 \
    || { show_log_tail "$BUILD_DIR/export.log"; error "xcodebuild -exportArchive failed"; }

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
[ -d "$APP_PATH" ] || { show_log_tail "$BUILD_DIR/export.log"; error "Exported .app not found at $APP_PATH"; }

# Sanity: extract version from the exported app's Info.plist
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
BUILT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)
echo "Built app: CFBundleShortVersionString=$BUILT_VERSION CFBundleVersion=$BUILT_BUILD"

# --- Verify codesign ---------------------------------------------------------

echo "Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tee "$BUILD_DIR/codesign-verify.log" \
    || { show_log_tail "$BUILD_DIR/codesign-verify.log"; error "codesign verification failed"; }

# --- Create DMG --------------------------------------------------------------

DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

echo "Creating DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -a "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    2>&1 | tee "$BUILD_DIR/dmg.log" | tail -5 \
    || { show_log_tail "$BUILD_DIR/dmg.log"; error "hdiutil create failed"; }
rm -rf "$DMG_STAGING"
[ -f "$DMG_PATH" ] || error "DMG not created at $DMG_PATH"

# --- Notarize and staple -----------------------------------------------------

echo "Submitting for notarization (this can take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait \
    2>&1 | tee "$BUILD_DIR/notarize.log" \
    || { show_log_tail "$BUILD_DIR/notarize.log"; error "notarytool submit failed"; }

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH" 2>&1 | tee "$BUILD_DIR/staple.log" \
    || { show_log_tail "$BUILD_DIR/staple.log"; error "stapler staple failed"; }

# --- Sparkle signature -------------------------------------------------------

echo "Signing DMG for Sparkle..."
"$SPARKLE_TOOLS_DIR/bin/sign_update" "$DMG_PATH" > "$BUILD_DIR/sparkle-signature.txt" \
    || { cat "$BUILD_DIR/sparkle-signature.txt" >&2; error "sign_update failed"; }
cat "$BUILD_DIR/sparkle-signature.txt"

# --- GitHub release ----------------------------------------------------------

TAG="$VERSION"

echo ""
read -r -p "Release title (press Enter to use '$APP_NAME $VERSION'): " RELEASE_TITLE
if [ -z "$RELEASE_TITLE" ]; then
    RELEASE_TITLE="$APP_NAME $VERSION"
fi
read -r -p "Release subtitle (optional, press Enter to skip): " RELEASE_SUBTITLE || true

# Tag and push
cd "$PROJECT_DIR"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists locally."
else
    git tag "$TAG" || error "git tag failed"
fi
git push origin "$TAG" || error "git push tag failed"

# Build release notes: optional subtitle header + auto-generated notes.
NOTES_FILE="$BUILD_DIR/release-notes.md"
: > "$NOTES_FILE"
if [ -n "$RELEASE_SUBTITLE" ]; then
    {
        echo "$RELEASE_SUBTITLE"
        echo ""
    } > "$NOTES_FILE"
fi

echo "Creating GitHub release..."
if [ -s "$NOTES_FILE" ]; then
    gh release create "$TAG" "$DMG_PATH" \
        --repo "$GITHUB_REPO" \
        --title "$RELEASE_TITLE" \
        --notes-file "$NOTES_FILE" \
        --generate-notes \
        2>&1 | tee "$BUILD_DIR/gh-release.log" \
        || { show_log_tail "$BUILD_DIR/gh-release.log"; error "gh release create failed"; }
else
    gh release create "$TAG" "$DMG_PATH" \
        --repo "$GITHUB_REPO" \
        --title "$RELEASE_TITLE" \
        --generate-notes \
        2>&1 | tee "$BUILD_DIR/gh-release.log" \
        || { show_log_tail "$BUILD_DIR/gh-release.log"; error "gh release create failed"; }
fi

# --- Generate appcast.xml ----------------------------------------------------

APPCAST_DIR="$BUILD_DIR/appcast-assets"
mkdir -p "$APPCAST_DIR"

# Copy existing appcast so generate_appcast appends to it instead of duplicating prior releases
if [ -f "$PROJECT_DIR/appcast.xml" ]; then
    cp "$PROJECT_DIR/appcast.xml" "$APPCAST_DIR/"
fi

# Only include the new DMG (not prior releases, to avoid "Duplicate updates" errors)
cp "$DMG_PATH" "$APPCAST_DIR/"

echo "Generating appcast.xml..."
"$SPARKLE_TOOLS_DIR/bin/generate_appcast" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/$TAG/" \
    -o "$APPCAST_DIR/appcast.xml" \
    "$APPCAST_DIR" \
    2>&1 | tee "$BUILD_DIR/appcast.log" \
    || { show_log_tail "$BUILD_DIR/appcast.log"; error "generate_appcast failed"; }

cp "$APPCAST_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "Update appcast for $VERSION" || error "git commit for appcast failed"
git push origin HEAD || error "git push for appcast failed"

echo ""
echo "Done. $APP_NAME $VERSION released."
echo "  DMG:      $DMG_PATH"
echo "  Appcast:  $PROJECT_DIR/appcast.xml"
echo "  Release:  https://github.com/$GITHUB_REPO/releases/tag/$TAG"
