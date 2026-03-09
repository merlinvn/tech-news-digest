#!/usr/bin/env python3
"""
Produce a JSON summary of top articles per topic.

Usage:
    python3 summarize-merged.py \
        --input /tmp/td-merged.json \
        --top 10 \
        --output output.json
"""

import json
import argparse
from pathlib import Path


def summarize(data: dict, top_n: int = 10, topic_filter: str = None):
    """Return structured JSON summary of merged data."""

    result = {"metadata": data.get("output_stats", {}), "topics": {}}

    topics = data.get("topics", {})

    for topic_id, topic_data in topics.items():
        if topic_filter and topic_id != topic_filter:
            continue

        articles = topic_data.get("articles", [])
        if not isinstance(articles, list):
            continue

        sorted_articles = sorted(
            [a for a in articles if isinstance(a, dict)],
            key=lambda a: a.get("quality_score", 0),
            reverse=True,
        )

        top_articles = []

        for a in sorted_articles[:top_n]:
            article = {
                "title": a.get("title"),
                "source": a.get("source_name"),
                "source_type": a.get("source_type"),
                "quality_score": a.get("quality_score", 0),
                "link": a.get("link") or a.get("reddit_url") or a.get("external_url"),
                "snippet": a.get("snippet") or a.get("summary"),
                "metrics": a.get("metrics", {}),
            }

            if a.get("display_name"):
                article["display_name"] = a.get("display_name")

            if a.get("score") is not None:
                article["reddit_score"] = a.get("score")

            if a.get("num_comments") is not None:
                article["num_comments"] = a.get("num_comments")

            top_articles.append(article)

        result["topics"][topic_id] = {
            "total_articles": len(articles),
            "top_articles": top_articles,
        }

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Summarize merged JSON into JSON output"
    )
    parser.add_argument("--input", "-i", type=Path, default=Path("/tmp/td-merged.json"))
    parser.add_argument("--top", "-n", type=int, default=10)
    parser.add_argument("--topic", "-t", type=str, default=None)
    parser.add_argument(
        "--output", "-o", type=Path, default=None, help="Output JSON file"
    )
    args = parser.parse_args()

    if not args.input.exists():
        raise SystemExit(f"Error: {args.input} not found")

    with open(args.input) as f:
        data = json.load(f)

    result = summarize(data, top_n=args.top, topic_filter=args.topic)

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, "w") as f:
            json.dump(result, f, indent=2)
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
