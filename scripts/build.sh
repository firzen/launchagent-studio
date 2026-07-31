#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/LaunchAgent Studio.app"
CONTENTS_DIR="$APP_PATH/Contents"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

swiftc \
  -parse-as-library \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  "$PROJECT_DIR/Sources/LaunchAgentStudio/LaunchAgentStudio.swift" \
  -o "$CONTENTS_DIR/MacOS/LaunchAgentStudio"

cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "Built: $APP_PATH"
