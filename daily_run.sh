#!/bin/bash

source .env
TODAY=$(date +%Y-%m-%d)

python3 scripts/run-pipeline.py --hours 24 --freshness pd --default ./config/neo --archive-dir ./archive/tech-news-digest --verbose --enrich

python3 scripts/summarize-merged-json.py \
  --input /tmp/td-merged.json \
  --top 10 \
  --output archive/tech-news-digest/daily-"${TODAY}".json

mkdir -p archive/tech-news-digest-final

(
  sed "s/{{DATE}}/${TODAY}/g" prompts/newsletter_prompt.txt
  echo ""
  echo "Dữ liệu JSON:"
  cat archive/tech-news-digest/daily-"${TODAY}".json
) | gemini -m gemini-3-flash-preview \
  >archive/tech-news-digest-final/newsletter-"${TODAY}".md

curl -X POST "$N8N_WEBHOOK_URL" \
  -H "Content-Type: text/plain" \
  --data-binary @archive/tech-news-digest-final/newsletter-"${TODAY}".md
