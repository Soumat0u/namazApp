#!/usr/bin/env bash
# Yeni sürümü kablosuz yayımlar: pubspec.yaml'daki build numarasını artırır
# (version: x.y.z+N), APK'yı sunucunun anahtarı gömülü olarak derler ve
# safak-lenovo:~/.local/share/notlar/apk/namaz/ altına koyar. Uygulama bir
# sonraki açılışta "Yeni sürüm hazır" çubuğunu gösterir (lib/services/updater.dart).
#
#   ./publish.sh            # küçük düzeltme: 1.5.0 → 1.5.1
#   ./publish.sh minor      # yeni özellik:   1.5.1 → 1.6.0
#   ./publish.sh major      # büyük değişiklik: 1.6.0 → 2.0.0
#   ./publish.sh 1.7.0      # sürüm adını elle ver
#
# Build numarası (+N) her yayında kendiliğinden artar; Android güncellemeyi ona bakarak tanır.
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
IFS=. read -r maj min pat <<<"$name"
case "${1:-patch}" in
  patch) name="$maj.$min.$((pat + 1))" ;;
  minor) name="$maj.$((min + 1)).0" ;;
  major) name="$((maj + 1)).0.0" ;;
  [0-9]*.[0-9]*.[0-9]*) name=$1 ;;
  *) echo "kullanım: ./publish.sh [patch|minor|major|x.y.z]" >&2; exit 1 ;;
esac
code=$((code + 1))
sed -i -E "s/^version: .*/version: $name+$code/" pubspec.yaml
echo "sürüm $name ($code) derleniyor"

JAVA_HOME=${JAVA_HOME:-$HOME/.local/jdk} flutter build apk --release --flavor deneme --target-platform android-arm64 \
  --dart-define=UPDATE_TOKEN="$(cat "$TOKEN_FILE")"
apk=build/app/outputs/flutter-apk/app-deneme-release.apk

# Önce APK, sonra onu gösteren sürüm bilgisi; ikisi de tek hamlede değişir
ssh "$HOST" "mkdir -p $DEST"
scp -q "$apk" "$HOST:$DEST/app.apk.tmp"
printf '{"version": %d, "name": "%s"}\n' "$code" "$name" | ssh "$HOST" "cat > $DEST/version.json.tmp"
ssh "$HOST" "cd $DEST && mv app.apk.tmp app.apk && mv version.json.tmp version.json"
echo "yayımlandı: $name ($code), $(du -h "$apk" | cut -f1)"
