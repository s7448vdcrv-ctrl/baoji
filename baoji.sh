#!/bin/sh
# 今日战绩查询 + Bark 推送（GitHub Actions 版）
ORIGIN="https://www.rwnwi5.com"
FN="CTO7"
ADMIN="HaoHao&1"
PRICE="2.5"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126 Safari/537.36"
TODAY="$(TZ=Asia/Shanghai date +%F)"
TMP="$(mktemp -d)"
i=0
printf '%s\n' "$ACCOUNTS" | while IFS='|' read -r user pass; do
  [ -z "$user" ] && continue
  i=$((i+1))
  (
    resp="$(curl -s -m 20 -H "Content-Type: application/json" -H "User-Agent: $UA" \
      -d "{\"username\":\"$user\",\"password\":\"$pass\"}" "$ORIGIN/zb/manager/login")"
    token="$(printf '%s' "$resp" | grep -oE '"token":"[^"]+"' | head -n1 | cut -d'"' -f4)"
    a=""
    if [ -n "$token" ]; then
      r="$(curl -s -m 20 -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
        -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: $UA" \
        -d "{\"queryDates\":[\"$TODAY\"],\"functionName\":\"$FN\",\"zbUserName\":\"$user\",\"adminUserName\":\"$ADMIN\"}" \
        "$ORIGIN/zb/manager/task/historyList")"
      a="$(printf '%s' "$r" | grep -oE '"hasReceivedCnt": *[0-9]+' | head -n1 | grep -oE '[0-9]+')"
      if [ -n "$a" ]; then
        b="$(printf '%s' "$r" | grep -oE '"realSucCnt": *[0-9]+' | head -n1 | grep -oE '[0-9]+')"
        c="$(printf '%s' "$r" | grep -oE '"realFailCnt": *[0-9]+' | head -n1 | grep -oE '[0-9]+')"
        printf '%s %s %s\n' "$a" "${b:-0}" "${c:-0}" > "$TMP/r_$i"
      fi
    fi
    [ -n "$a" ] || echo NA > "$TMP/r_$i"
  ) &
  [ $((i % 10)) -eq 0 ] && wait
done
wait
total=0; suc=0; failcnt=0
for f in "$TMP"/r_*; do
  [ -e "$f" ] || continue
  set -- $(cat "$f")
  [ "$1" = "NA" ] && continue
  total=$((total+$1)); suc=$((suc+$2)); failcnt=$((failcnt+$3))
done
rm -rf "$TMP"
earn="$(awk "BEGIN{printf \"%.2f\", $suc * $PRICE}")"
cur="$(TZ=Asia/Shanghai date +%F) $total $suc $failcnt"
prev="$(cat last.txt 2>/dev/null)"
if [ "$prev" != "$cur" ] && [ -n "$prev" ]; then
  curl -s -m 20 -X POST "https://api.day.app/push" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "{\"device_key\":\"$BARK_KEY\",\"title\":\"今日战绩\",\"body\":\"总数量：$total\\n成功：$suc\\n失败：$failcnt\\n收益：$earn\"}"
fi
echo "$cur" > last.txt
