#!/bin/bash
set -e
echo "=== Installing Android SDK Components and Flutter ==="

export JAVA_HOME=/opt/jdk-17
export ANDROID_HOME=/opt/android-sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/usr/local/bin:/usr/bin:/bin

chmod +x -R "$ANDROID_HOME/cmdline-tools/latest/bin"

echo "1. Installing Android SDK components..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;26.1.10909125" "cmake;3.22.1"

echo "2. Setting up Flutter SDK..."
if [ ! -d "/opt/flutter" ]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git /opt/flutter
fi

export PATH=$PATH:/opt/flutter/bin
git config --global --add safe.directory /opt/flutter
flutter config --no-analytics
flutter config --android-sdk "$ANDROID_HOME"

echo "3. Accepting Flutter Android licenses..."
yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

cat << 'PROFILE_EOF' > /etc/profile.d/edgerag_env.sh
export JAVA_HOME=/opt/jdk-17
export ANDROID_HOME=/opt/android-sdk
export ANDROID_NDK_HOME=/opt/android-sdk/ndk/26.1.10909125
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/opt/flutter/bin:/usr/local/bin:/usr/bin:/bin:$PATH
PROFILE_EOF

echo "4. Running flutter doctor:"
flutter doctor -v
echo "=== BUILD ENVIRONMENT READY ==="
