#!/bin/bash
set -e

# idea-refine skill 用の ideas directory を初期化する。

IDEAS_DIR="docs/ideas"

if [ ! -d "$IDEAS_DIR" ]; then
  mkdir -p "$IDEAS_DIR"
  echo "ディレクトリを作成しました: $IDEAS_DIR" >&2
else
  echo "ディレクトリは既に存在します: $IDEAS_DIR" >&2
fi

echo "{\"status\": \"ready\", \"directory\": \"$IDEAS_DIR\"}"
