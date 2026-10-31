#!/usr/bin/env bash
# PreToolUse 훅 (matcher: Agent). 운영 정책 "서브에이전트는 항상 Opus"를 하네스 수준에서 강제한다.
# Agent 호출의 model 파라미터가 "opus"가 아니면 exit 2로 막고, 이유를 stderr로 돌려준다(Claude가 보고 다시 호출한다).
# python3가 없거나 입력을 못 읽으면 통과시킨다(fail-open). 끄려면 settings.json의 hooks에서 이 항목을 지운다.
input="$(cat)"
model="$(printf '%s' "$input" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    ti=d.get("tool_input") or {}
    print(ti.get("model") or "")
except Exception:
    print("__skip__")' 2>/dev/null)" || exit 0
case "$model" in
  __skip__|"") [ "$model" = "__skip__" ] && exit 0 ;;
esac
if [ "$model" != "opus" ]; then
  printf '%s\n' "라우팅 정책: 서브에이전트는 항상 Opus다. Agent 호출에 model: \"opus\" 와 effort(low|medium|high|xhigh, 사유가 있으면 max) 를 명시해 다시 호출하라. (현재 model: '${model:-없음}')" >&2
  exit 2
fi
exit 0
