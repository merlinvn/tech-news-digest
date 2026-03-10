#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "===== $(date) Starting news pipeline ====="

if [ ! -f ".env" ]; then
  echo "Error: .env file not found"
  exit 1
fi

set -a
source .env
set +a

TODAY=$(date +%Y-%m-%d)

ARCHIVE_DIR="./archive/tech-news-digest"
FINAL_DIR="./archive/tech-news-digest-final"

mkdir -p "$FINAL_DIR"

python3 scripts/run-pipeline.py --hours 24 --freshness pd --default ./config/neo --archive-dir "$ARCHIVE_DIR" --verbose --enrich

python3 scripts/summarize-merged-json.py \
  --input /tmp/td-merged.json \
  --top 10 \
  --output "$ARCHIVE_DIR/daily-${TODAY}.json"

(
  sed "s/{{DATE}}/${TODAY}/g" prompts/newsletter_prompt.txt
  echo ""
  echo "JSON data:"
  cat "$ARCHIVE_DIR/daily-${TODAY}.json"
) | gemini -m gemini-3-flash-preview \
  >"$FINAL_DIR/newsletter-${TODAY}.md"

curl -f -X POST "$N8N_WEBHOOK_URL" \
  -H "Content-Type: text/plain" \
  --data-binary @"$FINAL_DIR/newsletter-${TODAY}.md"

echo "===== $(date) Pipeline finished ====="
