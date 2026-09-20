#!/bin/bash
set -e
echo "=== Fast Toolchain Provisioning ==="

# 1. OpenJDK 17
if [ ! -f "/opt/jdk-17/bin/java" ]; then
    echo "1. Downloading OpenJDK 17..."
    mkdir -p /opt/jdk-17
    curl -L --retry 3 "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.12_7.tar.gz" -o /tmp/jdk17.tar.gz
    tar -xzf /tmp/jdk17.tar.gz -C /opt/jdk-17 --strip-components=1
    rm -f /tmp/jdk17.tar.gz
fi
export JAVA_HOME=/opt/jdk-17
export PATH=$JAVA_HOME/bin:$PATH
echo "Java version:"
java -version

# 2. Android Command-line Tools
export ANDROID_HOME=/opt/android-sdk
if [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo "2. Downloading Android Command-line Tools..."
    mkdir -p /tmp/cmdline_unzipped
    curl -L --retry 3 "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o /tmp/cmdline.zip
    python3 -m zipfile -e /tmp/cmdline.zip /tmp/cmdline_unzipped
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    cp -r /tmp/cmdline_unzipped/cmdline-tools/* "$ANDROID_HOME/cmdline-tools/latest/"
    rm -rf /tmp/cmdline.zip /tmp/cmdline_unzipped
fi
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# 3. Flutter SDK
if [ ! -f "/opt/flutter/bin/flutter" ]; then
    echo "3. Downloading Flutter SDK..."
    curl -L --retry 3 "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz" | tar -xJ -C /opt
fi
export PATH=$PATH:/opt/flutter/bin
git config --global --add safe.directory /opt/flutter
flutter config --no-analytics
flutter config --android-sdk "$ANDROID_HOME"

# 4. Android SDK components
echo "4. Installing Android SDK components (API 34, Build Tools 34, NDK 26, CMake)..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;26.1.10909125" "cmake;3.22.1"

# 5. Flutter Android Licenses
echo "5. Accepting Flutter Android licenses..."
yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

# 6. Profile script
cat << 'PROFILE_EOF' > /etc/profile.d/edgerag_env.sh
export JAVA_HOME=/opt/jdk-17
export ANDROID_HOME=/opt/android-sdk
export ANDROID_NDK_HOME=/opt/android-sdk/ndk/26.1.10909125
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/opt/flutter/bin:$PATH
PROFILE_EOF

echo "6. Flutter doctor check:"
flutter doctor -v
echo "=== TOOLCHAIN READY ==="
