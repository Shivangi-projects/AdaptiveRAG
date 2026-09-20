#!/bin/bash
set -e

echo "=== BUILDING EDGERAG RELEASE APK ==="
source /etc/profile.d/edgerag_env.sh
cd /mnt/c/Official/parser

flutter build apk --release --android-skip-build-dependency-validation

APK_SRC="/mnt/c/Official/parser/build/app/outputs/flutter-apk/app-release.apk"
APK_DEST="/mnt/c/Official/parser/EdgeRAG.apk"

if [ -f "$APK_SRC" ]; then
    cp "$APK_SRC" "$APK_DEST"
    echo "=== BUILD SUCCESSFUL ==="
    echo "EdgeRAG.apk created at $APK_DEST"
    ls -lh "$APK_DEST"
    echo "=== APK CONTENTS VERIFICATION ==="
    unzip -l "$APK_DEST" | grep -E "libedgerag.so|libonnxruntime.so|assets" | head -n 30
else
    echo "ERROR: APK not found at $APK_SRC"
    exit 1
fi
