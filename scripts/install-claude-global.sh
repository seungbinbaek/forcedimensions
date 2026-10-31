#!/usr/bin/env bash
# Claude Code 운영 정책(CLAUDE.md: Architect + Opus effort 라우팅), 에이전트, 스킬, 훅을 사용자 전역(~/.claude)에
# 설치해 이 컴퓨터의 모든 세션에 적용한다. 프로젝트와 무관하며, 이 스크립트가 있는 저장소의 파일을 자기 위치 기준으로 찾는다. 여러 번 실행해도 안전하다.
# 사용: bash scripts/install-claude-global.sh   (macOS, Linux, Git Bash. WSL에서 실행하면 WSL 쪽에 설치된다)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CLAUDE_HOME/backups/claude-global-$STAMP"   # 스킬·에이전트 폴더 밖에 둔다(안에 두면 스킬로 인식됨)

say() { printf '%s\n' "$*"; }
backup() {
  if [ -e "$1" ]; then
    rel="${1#"$CLAUDE_HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -r "$1" "$BACKUP_DIR/$rel"
  fi
}
# Git Bash에서는 C:/... 형태로, 그 외에는 그대로. claudeMdExcludes는 절대 경로 글롭이므로 슬래시만 쓴다.
abs_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

say "설치 대상: $CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills" "$CLAUDE_HOME/hooks"

# 1. 운영 정책 (저장소 CLAUDE.md) → ~/.claude/CLAUDE.md 의 마커 블록으로 병합 (사용자의 다른 내용은 보존, 멱등)
UMD="$CLAUDE_HOME/CLAUDE.md"
POLICY_SRC="$REPO_DIR/CLAUDE.md"
backup "$UMD"
if python3 -c 'import re' >/dev/null 2>&1; then
  PYTHONIOENCODING=utf-8 PYTHONUTF8=1 python3 - "$UMD" "$POLICY_SRC" <<'PY'
import re, sys, os
umd, src = sys.argv[1], sys.argv[2]
policy = open(src, encoding="utf-8").read().strip()
block = "<!-- claude-routing:policy:start -->\n" + policy + "\n<!-- claude-routing:policy:end -->"
cur = open(umd, encoding="utf-8").read() if os.path.exists(umd) else ""
pat = re.compile(r"<!-- claude-routing:policy:start -->.*?<!-- claude-routing:policy:end -->", re.S)
if pat.search(cur):
    cur = pat.sub(lambda m: block, cur)
else:
    if cur and not cur.endswith("\n"): cur += "\n"
    if cur: cur += "\n"
    cur += block + "\n"
open(umd, "w", encoding="utf-8").write(cur)
PY
else
  say "경고: python3 가 없어 ~/.claude/CLAUDE.md 병합을 못 했다. $POLICY_SRC 내용을 $UMD 에 직접 붙여 넣어라."
fi
say "1/5 ~/.claude/CLAUDE.md: 운영 정책 블록"

# 2. 에이전트 정의
for f in "$REPO_DIR"/.claude/agents/*.md; do
  backup "$CLAUDE_HOME/agents/$(basename "$f")"
  cp "$f" "$CLAUDE_HOME/agents/"
done
say "2/5 agents: $(ls "$REPO_DIR"/.claude/agents/*.md | xargs -n1 basename | tr '\n' ' ')"

# 3. 스킬 (전역 사본의 global-install 은 이 저장소의 절대 경로를 가리키게 바꾼다)
for d in "$REPO_DIR"/.claude/skills/*/; do
  n="$(basename "$d")"
  backup "$CLAUDE_HOME/skills/$n"
  rm -rf "$CLAUDE_HOME/skills/$n"
  cp -r "$d" "$CLAUDE_HOME/skills/$n"
done
GI="$CLAUDE_HOME/skills/global-install/SKILL.md"
if [ -f "$GI" ]; then
  python3 - "$GI" "$(abs_path "$REPO_DIR")" <<'PY' 2>/dev/null || true
import sys
p, repo = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read().replace("scripts/install-claude-global", repo + "/scripts/install-claude-global")
open(p, "w", encoding="utf-8").write(s)
PY
fi
say "3/5 skills: $(ls -d "$REPO_DIR"/.claude/skills/*/ | xargs -n1 basename | tr '\n' ' ')"

# 4. 훅 스크립트
backup "$CLAUDE_HOME/hooks/require-opus.sh"
cp "$REPO_DIR/.claude/hooks/require-opus.sh" "$CLAUDE_HOME/hooks/require-opus.sh"
chmod +x "$CLAUDE_HOME/hooks/require-opus.sh"
say "4/5 hooks/require-opus.sh"

# 5. settings.json 병합
SETTINGS="$CLAUDE_HOME/settings.json"
RULE_ABS="$(abs_path "$REPO_DIR/CLAUDE.md")"   # 이 저장소 안에서 정책이 두 번 로드되지 않게 제외
HOOK_CMD="bash \"$(abs_path "$CLAUDE_HOME")/hooks/require-opus.sh\""
HOOK_CMD_JSON="${HOOK_CMD//\"/\\\"}"   # 수동 안내문(JSON 조각)용 이스케이프
MANUAL='  "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "opus", "CLAUDE_CODE_FORK_SUBAGENT": "0" },
  "hooks": { "PreToolUse": [ { "matcher": "Agent", "hooks": [ { "type": "command", "command": "'"$HOOK_CMD_JSON"'", "timeout": 10 } ] } ] },
  "claudeMdExcludes": [ "'"$RULE_ABS"'" ]'
if python3 -c 'import json' >/dev/null 2>&1; then
  backup "$SETTINGS"
  if ! PYTHONIOENCODING=utf-8 PYTHONUTF8=1 python3 - "$SETTINGS" "$RULE_ABS" "$HOOK_CMD" <<'PY'
import json, sys, os
path, rule_abs, hook_cmd = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(path):
    raw = open(path, encoding="utf-8-sig").read().strip()
    if raw:
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"5/5 건너뜀: {path} 가 순수 JSON이 아니다({e}). 아래 항목을 직접 추가하라.")
            sys.exit(3)
env = data.setdefault("env", {})
cur = env.get("CLAUDE_CODE_SUBAGENT_MODEL")
if cur and cur != "opus":
    print(f"  기존 CLAUDE_CODE_SUBAGENT_MODEL={cur} 를 opus 로 덮어쓴다(백업 있음).")
env["CLAUDE_CODE_SUBAGENT_MODEL"] = "opus"
env.setdefault("CLAUDE_CODE_FORK_SUBAGENT", "0")
hooks = data.setdefault("hooks", {})
pre = hooks.setdefault("PreToolUse", [])
present = any("require-opus.sh" in (h.get("command") or "") for g in pre if isinstance(g, dict) for h in (g.get("hooks") or []) if isinstance(h, dict))
if not present:
    pre.append({"matcher": "Agent", "hooks": [{"type": "command", "command": hook_cmd, "timeout": 10, "statusMessage": "서브에이전트 모델 확인 (Opus 고정)"}]})
ex = data.setdefault("claudeMdExcludes", [])
if rule_abs not in ex:
    ex.append(rule_abs)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("5/5 settings.json: env.CLAUDE_CODE_SUBAGENT_MODEL=opus, env.CLAUDE_CODE_FORK_SUBAGENT=0, PreToolUse 훅, claudeMdExcludes += " + rule_abs)
if "CLAUDE_CODE_EFFORT_LEVEL" in env:
    print("경고: settings.json env 에 CLAUDE_CODE_EFFORT_LEVEL 이 있다. 에이전트별 effort 가 모두 무시되므로 지우기를 권한다.")
PY
  then
    say "$MANUAL"
  fi
else
  say "5/5 건너뜀: 동작하는 python3 가 없어 settings.json 을 자동 병합하지 못했다. 아래를 $SETTINGS 에 직접 추가:"
  say "$MANUAL"
fi

if [ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]; then
  say "경고: 환경변수 CLAUDE_CODE_EFFORT_LEVEL=$CLAUDE_CODE_EFFORT_LEVEL 이 설정돼 있다. 에이전트별 effort 가 모두 무시되므로 해제를 권한다."
fi

say ""
say "완료. 백업: $BACKUP_DIR (변경된 파일이 있을 때만 생성)"
say "새 세션에서 확인:"
say "  /context                                  -> Memory files 에 ~/.claude/CLAUDE.md 가 보여야 한다"
say "  claude plugin validate ~/.claude/agents   -> 에이전트 파일 문법 검사"
say "  /tasks                                    -> 위임 후 모델 Opus 와 effort 확인"
say "저장소의 정책이나 스킬을 고치거나 pull 한 뒤에는 이 스크립트를 다시 실행한다."
