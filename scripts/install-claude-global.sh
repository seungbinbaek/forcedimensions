#!/usr/bin/env bash
# 이 저장소의 Claude Code 운영 정책(Architect + Opus effort 라우팅), 에이전트, 스킬을
# 사용자 전역(~/.claude)에 설치해 이 컴퓨터의 모든 세션에 적용한다. 여러 번 실행해도 안전하다.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }
backup() { if [ -e "$1" ]; then cp -r "$1" "$1.bak-$STAMP"; say "  백업: $1 -> $1.bak-$STAMP"; fi; }

say "설치 대상: $CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/rules" "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills"

# 1. 운영 정책 (사용자 레벨 규칙 = 모든 프로젝트에 로드)
backup "$CLAUDE_HOME/rules/routing.md"
cp "$REPO_DIR/.claude/rules/routing.md" "$CLAUDE_HOME/rules/routing.md"
say "1/4 rules/routing.md 설치"

# 2. 에이전트 정의
for f in "$REPO_DIR"/.claude/agents/*.md; do
  backup "$CLAUDE_HOME/agents/$(basename "$f")"
  cp "$f" "$CLAUDE_HOME/agents/"
done
say "2/4 agents 설치: $(ls "$REPO_DIR"/.claude/agents/*.md | xargs -n1 basename | tr '\n' ' ')"

# 3. 스킬
for d in "$REPO_DIR"/.claude/skills/*/; do
  n="$(basename "$d")"
  backup "$CLAUDE_HOME/skills/$n"
  rm -rf "$CLAUDE_HOME/skills/$n"
  cp -r "$d" "$CLAUDE_HOME/skills/$n"
done
say "3/4 skills 설치: $(ls -d "$REPO_DIR"/.claude/skills/*/ | xargs -n1 basename | tr '\n' ' ')"

# 4. settings.json 병합
SETTINGS="$CLAUDE_HOME/settings.json"
RULE_ABS="$REPO_DIR/.claude/rules/routing.md"
if command -v python3 >/dev/null 2>&1; then
  backup "$SETTINGS"
  python3 - "$SETTINGS" "$RULE_ABS" <<'PY'
import json, sys, os
path, rule_abs = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        raw = f.read().strip()
    data = json.loads(raw) if raw else {}
env = data.setdefault("env", {})
env.setdefault("CLAUDE_CODE_SUBAGENT_MODEL", "opus")
ex = data.setdefault("claudeMdExcludes", [])
if rule_abs not in ex:
    ex.append(rule_abs)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("4/4 settings.json 병합: env.CLAUDE_CODE_SUBAGENT_MODEL=opus, claudeMdExcludes += " + rule_abs)
PY
else
  say "4/4 건너뜀: python3가 없어 settings.json을 자동 병합하지 못했다. 아래를 $SETTINGS 에 직접 추가:"
  say '  "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "opus" },'
  say "  \"claudeMdExcludes\": [\"$RULE_ABS\"]"
fi

# 경고: 전역 effort 환경변수는 에이전트별 effort를 무시하게 만든다
if [ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]; then
  say "경고: CLAUDE_CODE_EFFORT_LEVEL=$CLAUDE_CODE_EFFORT_LEVEL 이 설정돼 있다. 에이전트별 effort가 모두 무시되므로 해제를 권장한다."
fi
if grep -q '"CLAUDE_CODE_EFFORT_LEVEL"' "$SETTINGS" 2>/dev/null; then
  say "경고: $SETTINGS 의 env에 CLAUDE_CODE_EFFORT_LEVEL 이 있다. 에이전트별 effort가 무시된다."
fi

say ""
say "완료. 새 세션에서 확인:"
say "  /context  -> Memory files 에 ~/.claude/rules/routing.md 가 보여야 한다"
say "  /agents   -> worker, verifier, researcher, designer, Explore"
say "  /tasks    -> 위임 후 모델 Opus 와 effort 확인"
