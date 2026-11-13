#!/bin/sh
# Build + sign the countdown dialog APK (no Gradle). Output: app/tvoff.apk
# Bump versionCode in AndroidManifest.xml before reinstalling over an older build.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)
JAR=$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)/android.jar

rm -rf build && mkdir -p build/obj build/dex
javac --release 11 -classpath "$JAR" -d build/obj src/dev/local/tvoff/*.java
"$BT/d8" --lib "$JAR" --min-api 26 --output build/dex $(find build/obj -name '*.class')
"$BT/aapt2" link -o build/unsigned.apk -I "$JAR" --manifest AndroidManifest.xml \
  --min-sdk-version 26 --target-sdk-version 34
(cd build/dex && zip -q ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 build/unsigned.apk build/aligned.apk
"$BT/apksigner" sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android \
  --out tvoff.apk build/aligned.apk
rm -rf build
echo "built $(pwd)/tvoff.apk"
