---
name: global-install
description: 이 저장소의 운영 정책(.claude/rules/routing.md), Opus 에이전트 정의, 스킬을 사용자 전역(~/.claude)에 설치해 이 컴퓨터의 모든 Claude Code 세션에 적용한다. 사용자가 "전역 적용해줘", "모든 세션에 적용", "다른 프로젝트에도 쓰게 해줘"라고 할 때 사용.
---
# global-install: 모든 로컬 세션에 적용

## 실행
- 클라우드 세션 판별: 환경변수 `CLAUDE_CODE_REMOTE=true`이면 클라우드다. 컨테이너의 ~/.claude는 세션이 끝나면 사라지므로 실행하지 않고 이렇게 안내한다: "로컬 저장소에서 `git fetch origin <브랜치> && git checkout <브랜치>` 후 그 폴더에서 Claude Code를 열고 '전역 적용해줘'". 브랜치 이름은 `git branch --show-current`로 채운다.
- macOS, Linux, Git Bash: `bash scripts/install-claude-global.sh`
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File scripts/install-claude-global.ps1`
- WSL 안에서 실행하면 WSL의 ~/.claude에 설치된다. Windows 쪽 Claude Code에 적용하려면 PowerShell 스크립트를 쓴다.
- 전역 설치 후에는 이 스킬이 다른 저장소에서도 발동한다. 그때는 스크립트 경로가 이 저장소의 절대 경로로 바뀌어 있으니 그 경로를 그대로 실행한다. 경로가 없으면 저장소를 다시 클론하라고 안내한다.

## 스크립트가 하는 일
1. `.claude/rules/routing.md` → `~/.claude/rules/routing.md` (사용자 레벨 규칙은 모든 프로젝트에 로드된다)
2. `.claude/agents/*.md` → `~/.claude/agents/`
3. `.claude/skills/*` → `~/.claude/skills/`
4. `.claude/hooks/require-opus.sh` → `~/.claude/hooks/` (Agent 호출에 `model: "opus"`가 없으면 막는 PreToolUse 훅)
5. `~/.claude/settings.json`에 병합: `env.CLAUDE_CODE_SUBAGENT_MODEL = "opus"`(기존 값이 달라도 덮어쓴다), `env.CLAUDE_CODE_FORK_SUBAGENT = "0"`, PreToolUse 훅, 그리고 이 저장소 `routing.md`의 절대 경로를 `claudeMdExcludes`에 추가(이 저장소 안에서 같은 규칙이 두 번 로드되는 것을 막는다).
6. `~/.claude/CLAUDE.md`에 `# Compact instructions` 블록을 마커와 함께 추가한다(이미 있으면 갱신).
7. 기존 파일은 `~/.claude/backups/claude-global-<시각>/`에 백업한다. 스킬 폴더 안에 백업을 두면 스킬로 인식되므로 그 밖에 둔다. 여러 번 실행해도 안전하다.

## 실행 후 확인 (사용자에게 안내)
- 새 세션을 열고 `/context`에서 Memory files에 `~/.claude/rules/routing.md`가 보이는지 확인.
- `ls ~/.claude/agents`에 worker, verifier, researcher, designer, Explore, Plan이 있고 `claude plugin validate ~/.claude/agents`가 통과하는지 확인(`/agents`는 목록을 보여주지 않는다).
- 작업 하나를 위임시킨 뒤 `/tasks`로 모델이 Opus이고 effort가 적용됐는지 확인.
- `claude --version`이 2.1.292 미만이면 `claude update`. 호출 시 effort 지정이 그 버전부터 지원된다.

## 주의
- 설치 후 이 컴퓨터에서는 저장소의 routing.md(claudeMdExcludes로 제외)와 같은 이름의 스킬(개인 스킬이 프로젝트 스킬보다 우선) 대신 전역 사본이 쓰인다. 저장소에서 정책이나 스킬을 고치거나 pull한 뒤에는 스크립트를 다시 실행한다.
- `CLAUDE_CODE_EFFORT_LEVEL` 환경변수가 설정돼 있으면 에이전트별 effort가 무시된다. 스크립트가 감지하면 경고한다.
- 모든 서브에이전트를 강제로 Opus에 고정하려면 `~/.claude/settings.json`의 env에 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE: "1"`을 추가할 수 있다. 단, 이 모드에서 에이전트별 effort가 유지되는지는 공식 문서에 명시되지 않았으므로 켠 뒤 `/tasks`로 확인한다.
