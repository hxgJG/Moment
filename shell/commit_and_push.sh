#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

git add -A
git commit --no-verify -m "${1:-update}"
git push git@github.com:hxgJG/Moment.git "$(git branch --show-current)"
