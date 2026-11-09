#!/usr/bin/env bash
# iOS: パッケージ解決 → Dev / Prod スキームのビルド → Dev スキームでユニットテスト・UIテスト（UIテストは実環境用のため環境変数がなければスキップ）
#   使い方: ./scripts/ios-verify.sh [--skip-ui-tests] [--build-only]
# ログ: .logs/ios-verify-latest.log（エラー要約は .logs/ios-errors-latest.txt）
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$REPO_ROOT/.logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/ios-verify-latest.log"
ERRORS="$LOG_DIR/ios-errors-latest.txt"
: >"$LOG"; : >"$ERRORS"
exec > >(tee -a "$LOG") 2>&1

PROJECT="$REPO_ROOT/friend-search/friend-search.xcodeproj"
DERIVED="$REPO_ROOT/build/DerivedData"
SKIP_UI=false
BUILD_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --skip-ui-tests) SKIP_UI=true ;;
    --build-only) BUILD_ONLY=true ;;
  esac
done

echo "=== ios-verify $(date '+%Y-%m-%d %H:%M:%S')"
xcodebuild -version

DEST_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
best = None
for runtime, items in devices.items():
    if "iOS" not in runtime:
        continue
    for d in items:
        # iPhone Duo は TabBar が出ず UI テストの前提と合わないため対象外
        if d.get("isAvailable") and d["name"].startswith("iPhone") and "Duo" not in d["name"]:
            key = (runtime, d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"])
print(best[1] if best else "")
')"
if [[ -z "$DEST_ID" ]]; then echo "ERROR: 利用可能な iPhone シミュレータがありません"; exit 1; fi
DEST="platform=iOS Simulator,id=$DEST_ID"
echo "destination: $DEST"

COMMON=(-project "$PROJECT" -derivedDataPath "$DERIVED" -skipMacroValidation -skipPackagePluginValidation)

step() {
  local name="$1"; shift
  echo; echo "------ $name ------"
  local out="$LOG_DIR/ios-$name.log"
  "$@" >"$out" 2>&1
  local rc=$?
  tail -25 "$out"
  if [[ $rc -ne 0 ]]; then
    { echo "### $name (exit $rc)"; grep -E "error:|failed|FAILED|Failing tests|✘|Test .* failed|Expectation failed" "$out" | head -80; } >>"$ERRORS"
    echo "FAILED: $name (詳細: .logs/ios-$name.log)"
  else
    echo "OK: $name"
  fi
  return $rc
}

RESULT=0
step list xcodebuild -list -project "$PROJECT" || RESULT=1
step resolve xcodebuild -resolvePackageDependencies "${COMMON[@]}" -scheme friend-search-Dev || RESULT=1
step build-dev xcodebuild build "${COMMON[@]}" -scheme friend-search-Dev -destination "$DEST" CODE_SIGNING_ALLOWED=NO || RESULT=1
step build-prod xcodebuild build "${COMMON[@]}" -scheme friend-search-Prod -destination "$DEST" CODE_SIGNING_ALLOWED=NO || RESULT=1

if ! $BUILD_ONLY && [[ $RESULT -eq 0 ]]; then
  if $SKIP_UI; then
    step test-dev xcodebuild test "${COMMON[@]}" -scheme friend-search-Dev -destination "$DEST" -only-testing:friend-searchTests || RESULT=1
  else
    step test-dev xcodebuild test "${COMMON[@]}" -scheme friend-search-Dev -destination "$DEST" || RESULT=1
  fi
fi

echo
if [[ $RESULT -eq 0 ]]; then echo "=== ios-verify: ALL OK"; else echo "=== ios-verify: FAILED（.logs/ios-errors-latest.txt）"; fi
exit $RESULT
