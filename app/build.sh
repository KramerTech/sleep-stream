#!/bin/sh
# Build + sign the countdown dialog APK (no Gradle). Output: app/tvoff.apk
# Bump versionCode in AndroidManifest.xml before reinstalling over an older build.
# Signs with app/release.keystore, generating a new key on first run (gitignored;
# keep it - updates must be signed with the same key to install over the app).
set -e
cd "$(dirname "$0")"
KS=release.keystore
KS_PASS=${KS_PASS:-android}
if [ ! -f "$KS" ]; then
  echo "no $KS - generating a new signing key"
  keytool -genkeypair -keystore "$KS" -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -alias tvoff -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=tvoff" >/dev/null
fi
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
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
  --out tvoff.apk build/aligned.apk
rm -rf build tvoff.apk.idsig
echo "built $(pwd)/tvoff.apk"
