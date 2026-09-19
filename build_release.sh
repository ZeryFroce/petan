#!/bin/bash
# 宠安 App 自动构建脚本
# 用法: ./build_release.sh "本次更新说明（一句话）"
# 行为: 自增 x.xx 版本号 -> 构建 release APK -> 以 app_vX.XX.apk 命名（不覆盖旧包）
#       -> 向 README.md 追加一条时间/版本/内容的更新日志
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# ---- 构建环境（JDK/SDK 路径，可用环境变量覆盖）----
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export PATH="/opt/homebrew/opt/openjdk@17/bin:/opt/homebrew/opt/flutter/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
FLUTTER="${FLUTTER:-/opt/homebrew/opt/flutter/bin/flutter}"

# ---- 读取并自增版本号 x.xx ----
VERSION_FILE="$PROJECT_DIR/.release_version"
if [ -f "$VERSION_FILE" ]; then
  CUR=$(cat "$VERSION_FILE")
else
  CUR="1.00"
fi
MAJOR=${CUR%%.*}
MINOR=${CUR#*.}
MINOR=$((10#$MINOR + 1))
if [ "$MINOR" -ge 100 ]; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
fi
NEW=$(printf "%d.%02d" "$MAJOR" "$MINOR")
PUBVER="${MAJOR}.${MINOR}.0"   # pubspec 需语义化版本，minor 不补零
CODE=$((MAJOR * 100 + MINOR))  # 单调递增版本号，便于覆盖安装

# ---- 更新 pubspec 版本（versionName = X.Y.0, versionCode = CODE）----
perl -i -pe "s/^version: .*/version: ${PUBVER}+${CODE}/" "$PROJECT_DIR/pubspec.yaml"
echo "$NEW" > "$VERSION_FILE"

# ---- 构建 Release APK（失败则回滚版本号，避免烧号）----
if ! "$FLUTTER" build apk --release; then
  echo "$CUR" > "$VERSION_FILE"
  echo "BUILD_FAILED（版本号已回滚至 $CUR，未产出新包）"
  exit 1
fi

# ---- 产出按版本命名的新文件（绝不覆盖已有包）----
RELEASES_DIR="$PROJECT_DIR/releases"
mkdir -p "$RELEASES_DIR"
SRC="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
DST="$RELEASES_DIR/app_v${NEW}.apk"
if [ -f "$DST" ]; then
  TS=$(date +%H%M%S)
  DST="$RELEASES_DIR/app_v${NEW}_${TS}.apk"
fi
cp "$SRC" "$DST"

# ---- 追加更新日志（写入 CHANGELOG.md，最新条目插在最上方）----
MSG="${1:-（未填写更新说明）}"
NOW=$(date "+%Y-%m-%d %H:%M")
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"
ENTRY="## v$NEW — $NOW
- 版本号: v$NEW (versionCode $CODE)
- 更新内容: $MSG
- 产物: GitHub Releases（本地: $DST）
"
if [ ! -f "$CHANGELOG" ]; then
  printf "# 更新日志 / Changelog\n\n自动构建产出，版本号格式 X.XX；每条记录构建时间、版本与更新内容。\n" > "$CHANGELOG"
fi
# 插入到第一个 "## " 版本条目之前；没有条目则追加到末尾
INSERT_LINE=$(grep -n '^## ' "$CHANGELOG" | head -1 | cut -d: -f1)
if [ -n "$INSERT_LINE" ]; then
  {
    head -n $((INSERT_LINE - 1)) "$CHANGELOG"
    printf "%s\n" "$ENTRY"
    tail -n +"$INSERT_LINE" "$CHANGELOG"
  } > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
else
  printf "\n%s\n" "$ENTRY" >> "$CHANGELOG"
fi

echo "BUILD_OK $DST"
