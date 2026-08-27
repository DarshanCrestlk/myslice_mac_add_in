#!/bin/bash
set -euo pipefail

# --- Configuration Variables ---
APP_NAME="Myslicetest"
BUNDLE_IDENTIFIER="org.crestmini2.myslicetest"
INSTALLER_IDENTIFIER="org.crestmini2.myslicetest.installer"
INSTALLER_NAME="${APP_NAME}_installer.pkg"
APP_PATH="./${APP_NAME}.app"
MANIFEST_FILE_PATH="./myslice_addin_manifest.xml"
MANIFEST_FILENAME=$(basename "$MANIFEST_FILE_PATH")

BUILD_DIR="./build"
PAYLOAD_DIR="${BUILD_DIR}/payload"
SCRIPTS_DIR="${BUILD_DIR}/scripts"
PAYLOAD_MANIFEST_DIR="$PAYLOAD_DIR/usr/local/myslice_manifests"
INSTALL_MANIFEST_DIR="/usr/local/myslice_manifests"

echo "--- Starting Installer Build Process ---"

# --- Pre-Build Sanity Checks ---
if [ ! -d "$APP_PATH" ]; then
  echo "❌ ERROR: '${APP_PATH}' not found."
  exit 1
fi

if [ ! -f "$MANIFEST_FILE_PATH" ]; then
  echo "❌ ERROR: Manifest file '${MANIFEST_FILE_PATH}' not found."
  exit 1
fi

# --- Cleanup ---
echo "🧹 Cleaning old builds..."
rm -rf "$BUILD_DIR" "./$INSTALLER_NAME"
mkdir -p "$PAYLOAD_DIR/Applications" "$PAYLOAD_MANIFEST_DIR" "$SCRIPTS_DIR"

# --- Copy Application ---
echo "📦 Copying ${APP_NAME}.app to payload..."
ditto "$APP_PATH" "$PAYLOAD_DIR/Applications/${APP_NAME}.app"

# --- Copy Manifest ---
echo "📄 Copying manifest to payload..."
cp "$MANIFEST_FILE_PATH" "$PAYLOAD_MANIFEST_DIR/"
chmod 644 "$PAYLOAD_MANIFEST_DIR/$MANIFEST_FILENAME"

# --- Create Postinstall Script ---
echo "🛠️ Creating postinstall script..."
cat <<'EOF' > "$SCRIPTS_DIR/postinstall"
#!/bin/bash
set -e
LOG="/tmp/myslicetest_postinstall.log"
APP_NAME="Myslicetest"
APP_PATH="/Applications/$APP_NAME.app"
INSTALL_MANIFEST_DIR="/usr/local/myslice_manifests"
MANIFEST_NAME="myslice_addin_manifest.xml"

echo "$(date): Starting postinstall..." >> "$LOG"

CURRENT_USER=${SUDO_USER:-$(stat -f%Su /dev/console)}
USER_HOME=$(dscl . -read /Users/$CURRENT_USER NFSHomeDirectory | cut -d " " -f2)

APP_SUPPORT="$USER_HOME/Library/Application Support/myslice"
LOG_DIR="$USER_HOME/Library/Logs/myslice"
mkdir -p "$APP_SUPPORT" "$LOG_DIR"
chown -R "$CURRENT_USER" "$APP_SUPPORT" "$LOG_DIR"

# Copy manifest
cp "$INSTALL_MANIFEST_DIR/$MANIFEST_NAME" "$APP_SUPPORT/"
chown "$CURRENT_USER" "$APP_SUPPORT/$MANIFEST_NAME"
chmod 644 "$APP_SUPPORT/$MANIFEST_NAME"

# Deploy to Office WEF
for app in Word Excel Powerpoint; do
  WEF="$USER_HOME/Library/Containers/com.microsoft.$app/Data/Documents/wef"
  mkdir -p "$WEF"
  cp "$APP_SUPPORT/$MANIFEST_NAME" "$WEF/"
  chown "$CURRENT_USER" "$WEF/$MANIFEST_NAME"
done

# Register app with Launch Services
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$APP_PATH" >> "$LOG" 2>&1 || true

# Refresh Launchpad
killall Dock || echo "⚠️ Could not restart Dock" >> "$LOG"

# Cleanup
rm -rf "$INSTALL_MANIFEST_DIR" || echo "⚠️ Could not clean temp manifest dir" >> "$LOG"

echo "$(date): Postinstall complete." >> "$LOG"
exit 0
EOF

chmod +x "$SCRIPTS_DIR/postinstall"

# --- Build Installer ---
echo "🏗️ Building .pkg installer..."
sudo pkgbuild \
  --root "$PAYLOAD_DIR" \
  --identifier "$INSTALLER_IDENTIFIER" \
  --version "1.0" \
  --install-location "/" \
  --scripts "$SCRIPTS_DIR" \
  "$BUILD_DIR/$INSTALLER_NAME"

echo "✅ Installer created: $BUILD_DIR/$INSTALLER_NAME"

# --- Inspect Package Contents ---
echo "🔍 Verifying .pkg contents..."
PKG_TMP="$BUILD_DIR/pkg_contents"
PAYLOAD_EXTRACT="$BUILD_DIR/payload_expanded"
rm -rf "$PKG_TMP" "$PAYLOAD_EXTRACT"
pkgutil --expand "$BUILD_DIR/$INSTALLER_NAME" "$PKG_TMP"

mkdir -p "$PAYLOAD_EXTRACT"
cat "$PKG_TMP/Payload" | gunzip -dc | cpio -i -D "$PAYLOAD_EXTRACT" 2>/dev/null

if [ ! -d "$PAYLOAD_EXTRACT/Applications/${APP_NAME}.app" ]; then
  echo "❌ ERROR: ${APP_NAME}.app not found in .pkg payload!"
  exit 1
fi

echo "📂 Contents of extracted payload:"
ls -R "$PAYLOAD_EXTRACT/Applications"

echo "--- ✅ Installer Build Completed Successfully ---"

