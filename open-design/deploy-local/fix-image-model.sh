#!/usr/bin/env bash
# ============================================================
# 自动修复新项目的 imageModel
# ============================================================
set -euo pipefail

DB="/home/wangwei/wei/workspacePy/design/open-design-main/.od/app.sqlite"
SQLITE="/home/wangwei/Android/Sdk/platform-tools/sqlite3"
TARGET_MODEL="custom-image"

# 更新所有 kind=image 但 imageModel 不是 custom-image 的项目
UPDATED=$("$SQLITE" "$DB" "
UPDATE projects
SET metadata_json = json_set(metadata_json, '$.imageModel', '${TARGET_MODEL}'),
    updated_at = (strftime('%s','now') * 1000)
WHERE json_extract(metadata_json, '$.kind') = 'image'
  AND (json_extract(metadata_json, '$.imageModel') IS NULL
       OR json_extract(metadata_json, '$.imageModel') != '${TARGET_MODEL}');
SELECT changes();
" 2>/dev/null)

if [ "${UPDATED:-0}" -gt 0 ]; then
    echo "[$(date '+%H:%M:%S')] Fixed $UPDATED project(s) → imageModel=${TARGET_MODEL}"
fi
