#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Updating apt and installing dependencies ==="
apt-get update -y
apt-get install -y openjdk-17-jdk git curl wget unzip xz-utils build-essential cmake ninja-build clang libglu1-mesa

echo "=== 2. Setting up Android SDK ==="
export ANDROID_HOME=/opt/android-sdk
mkdir -p "$ANDROID_HOME/cmdline-tools"

if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    echo "Downloading Android Command-line Tools..."
    mkdir -p /tmp/cmdline
    cd /tmp/cmdline
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    cp -r cmdline-tools/* "$ANDROID_HOME/cmdline-tools/latest/"
    rm -rf /tmp/cmdline
fi

export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

echo "Accepting licenses and installing SDK components..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;26.1.10909125" "cmake;3.22.1"

echo "=== 3. Setting up Flutter ==="
if [ ! -d "/opt/flutter" ]; then
    echo "Downloading Flutter SDK..."
    cd /opt
    curl -s https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz | tar -xJ
fi

export PATH="$PATH:/opt/flutter/bin"
git config --global --add safe.directory /opt/flutter
flutter config --no-analytics
flutter config --android-sdk "$ANDROID_HOME"

echo "Accepting Flutter Android licenses..."
yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

echo "=== 4. Setting up persistent environment variables ==="
cat << 'ENVEOC' > /etc/profile.d/flutter_android.sh
export ANDROID_HOME=/opt/android-sdk
export ANDROID_NDK_HOME=/opt/android-sdk/ndk/26.1.10909125
export PATH=$PATH:/opt/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
ENVEOC

echo "=== 5. Verifying Flutter Doctor ==="
/opt/flutter/bin/flutter doctor -v
echo "=== TOOLCHAIN SETUP COMPLETED SUCCESSFULLY ==="
