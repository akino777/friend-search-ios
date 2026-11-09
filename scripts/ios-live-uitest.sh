#!/usr/bin/env bash
# 実アプリから dev 環境へ接続する UI テストを、専用アカウントで実行する。
# アカウントは friend-search-infra の scripts/create-uitest-users.sh が用意する。
#   使い方: aws sso login --profile friend-dev && ./scripts/ios-live-uitest.sh [infraリポジトリのパス]
# ログ: .logs/ios-live-uitest.log
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFRA="${1:-$REPO_ROOT/../friend-search-infra}"
LOG_DIR="$REPO_ROOT/.logs"
LOG="$LOG_DIR/ios-live-uitest.log"
mkdir -p "$LOG_DIR"

"$INFRA/scripts/create-uitest-users.sh"
ACCOUNTS_FILE="$INFRA/.logs/uitest-accounts.json"

# ios-verify.sh と同じ基準でシミュレータを選ぶ（iPhone Duo は TabBar が出ないため対象外）
DEST_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
best = None
for runtime, items in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime:
        continue
    for d in items:
        if d.get("isAvailable") and d["name"].startswith("iPhone") and "Duo" not in d["name"]:
            key = (runtime, d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"])
print(best[1] if best else "")
')"
if [[ -z "$DEST_ID" ]]; then echo "ERROR: 利用可能な iPhone シミュレータがありません"; exit 1; fi

# TEST_RUNNER_ を付けた環境変数は、接頭辞を除いてテストプロセスへ渡される
echo "destination: ${DEST_ID} (log: ${LOG})"
set +e
TEST_RUNNER_FS_LIVE_ACCOUNTS="$(cat "$ACCOUNTS_FILE")" xcodebuild test \
  -project "$REPO_ROOT/friend-search/friend-search.xcodeproj" \
  -derivedDataPath "$REPO_ROOT/build/DerivedData" \
  -skipMacroValidation -skipPackagePluginValidation \
  -scheme friend-search-Dev \
  -destination "platform=iOS Simulator,id=$DEST_ID" \
  -parallel-testing-enabled NO \
  -only-testing:friend-searchUITests/LiveUITests >"$LOG" 2>&1
RC=$?
set -e
grep -E "Test Case .*(passed|failed|skipped)|error:|\*\* TEST" "$LOG" | cut -c1-240 || true
exit $RC
