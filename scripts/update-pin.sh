#!/usr/bin/env bash
# 把 config_template 里本仓库规则集的 @<ref> 固定到当前 HEAD。
# jsdelivr 对 @branch 的缓存 s-maxage 是 12 小时，pin 到具体 commit 才能立刻拿到新规则。
set -euo pipefail
cd "$(dirname "$0")/.."

REPO=GuGuDaDaDa/MyRuleSet
SHA=$(git rev-parse --short HEAD)

for f in sing-box/config_template/*.json; do
  sed -i -E "s#(jsdelivr\.net/gh/${REPO}@)[^/]+#\1${SHA}#g" "$f"
done

echo "已把模板里的 ${REPO}@* 更新为 @${SHA}："
grep -ho "jsdelivr\.net/gh/${REPO}@[^/]*" sing-box/config_template/*.json | sort -u
echo
echo "记得提交这次改动。"
