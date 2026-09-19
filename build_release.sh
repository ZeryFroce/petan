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

# ---- 二次确认（规则：是否发版/上传由主人本人决定，小改动不自动发版）----
# ASSUME_YES=1 可跳过确认（仅在主人明确同意发版后由助手使用）
if [ "${ASSUME_YES:-0}" != "1" ]; then
  printf "⚠️  将创建新版号 v%s (versionCode %s) 并同步到 GitHub，是否确认？[y/N] " "$NEW" "$CODE"
  read -r ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) ;;
    *)
      echo "已取消发版（版本号未消耗）。"
      echo "如仅本地试构建不占版本号，可自行运行：flutter build apk --release"
      exit 0
      ;;
  esac
fi

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

# ---- 同步到 GitHub（提交版本变更 → 推送 main → 打 tag 触发 Actions 自动发布 Release）----
# 说明：SKIP_SYNC=1 bash build_release.sh ... 可跳过同步（仅本地构建）
if [ "${SKIP_SYNC:-0}" = "1" ]; then
  echo "SYNC_SKIP 已按参数跳过 GitHub 同步"
else
  git add CHANGELOG.md pubspec.yaml
  if ! git diff --cached --quiet; then
    git commit -q -m "release: v$NEW — $MSG"
  fi
  RETRY=0
  until git push origin main 2>/dev/null; do
    RETRY=$((RETRY + 1))
    [ "$RETRY" -ge 3 ] && break
    sleep 3
  done
  if [ "$RETRY" -lt 3 ]; then
    if git tag -f "v$NEW" main && git push -f origin "v$NEW" 2>/dev/null; then
      echo "SYNC_OK 已同步 GitHub：main + tag v$NEW，Actions 将自动构建并发布 Release（约 6 分钟）"
    else
      echo "SYNC_WARN tag 推送失败，可稍后手动执行：git tag -f v$NEW main && git push -f origin v$NEW"
    fi
  else
    echo "SYNC_WARN main 推送失败，可稍后手动执行：git push origin main && git tag -f v$NEW main && git push -f origin v$NEW"
  fi
fi
