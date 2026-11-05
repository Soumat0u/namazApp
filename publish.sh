#!/usr/bin/env bash
# Yeni sürümü kablosuz yayımlar: pubspec.yaml'daki build numarasını artırır
# (version: x.y.z+N), APK'yı sunucunun anahtarı gömülü olarak derler ve
# safak-lenovo:~/.local/share/notlar/apk/namaz/ altına koyar. Uygulama bir
# sonraki açılışta "Yeni sürüm hazır" çubuğunu gösterir (lib/services/updater.dart).
#
#   ./publish.sh            # aynı sürüm adı, sonraki build numarası
#   ./publish.sh 1.1.0      # yeni sürüm adıyla
#
# Sürümler ~/.android/debug.keystore ile imzalanır: Android bir güncellemeyi
# yalnızca aynı anahtarla imzalanmışsa kabul eder, o dosyayı koruyun.
set -euo pipefail
cd "$(dirname "$0")"

HOST=${NOTLAR_HOST:-safak-lenovo}
DEST=.local/share/notlar/apk/namaz
TOKEN_FILE=~/.config/notlar/token

line=$(grep -E '^version: ' pubspec.yaml)
name=${line#version: }; name=${name%+*}
code=${line##*+}
name=${1:-$name}
code=$((code + 1))
sed -i -E "s/^version: .*/version: $name+$code/" pubspec.yaml
echo "sürüm $name ($code) derleniyor"

JAVA_HOME=${JAVA_HOME:-$HOME/.local/jdk} flutter build apk --release --target-platform android-arm64 \
  --dart-define=UPDATE_TOKEN="$(cat "$TOKEN_FILE")"
apk=build/app/outputs/flutter-apk/app-release.apk

# Önce APK, sonra onu gösteren sürüm bilgisi; ikisi de tek hamlede değişir
ssh "$HOST" "mkdir -p $DEST"
scp -q "$apk" "$HOST:$DEST/app.apk.tmp"
printf '{"version": %d, "name": "%s"}\n' "$code" "$name" | ssh "$HOST" "cat > $DEST/version.json.tmp"
ssh "$HOST" "cd $DEST && mv app.apk.tmp app.apk && mv version.json.tmp version.json"
echo "yayımlandı: $name ($code), $(du -h "$apk" | cut -f1)"
