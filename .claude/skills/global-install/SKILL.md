---
name: global-install
description: 이 저장소의 운영 정책(.claude/rules/routing.md), Opus 에이전트 정의, 스킬을 사용자 전역(~/.claude)에 설치해 이 컴퓨터의 모든 Claude Code 세션에 적용한다. 사용자가 "전역 적용해줘", "모든 세션에 적용", "다른 프로젝트에도 쓰게 해줘"라고 할 때 사용.
user-invocable: true
---
# global-install: 모든 로컬 세션에 적용

## 실행
- macOS, Linux, WSL, Git Bash: `bash scripts/install-claude-global.sh`
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File scripts/install-claude-global.ps1`
- 클라우드 세션에서는 실행하지 않는다(컨테이너의 ~/.claude는 세션이 끝나면 사라진다). 사용자에게 로컬에서 실행하라고 안내한다.

## 스크립트가 하는 일
1. `.claude/rules/routing.md` → `~/.claude/rules/routing.md` (사용자 레벨 규칙은 모든 프로젝트에 로드된다)
2. `.claude/agents/*.md` → `~/.claude/agents/`
3. `.claude/skills/*` → `~/.claude/skills/`
4. `~/.claude/settings.json`에 `env.CLAUDE_CODE_SUBAGENT_MODEL = "opus"`를 병합하고, 이 저장소의 `routing.md` 절대 경로를 `claudeMdExcludes`에 추가한다(이 저장소 안에서 같은 규칙이 두 번 로드되는 것을 막는다).
5. 기존 파일은 `.bak-<시각>`으로 백업한다. 여러 번 실행해도 안전하다.

## 실행 후 확인 (사용자에게 안내)
- 새 세션을 열고 `/context`에서 Memory files에 `~/.claude/rules/routing.md`가 보이는지 확인.
- `/agents`로 worker, verifier, researcher, designer, Explore가 보이는지 확인.
- 작업 하나를 위임시킨 뒤 `/tasks`로 모델이 Opus이고 effort가 적용됐는지 확인.
- `claude --version`이 2.1.292 미만이면 `claude update`. 호출 시 effort 지정이 그 버전부터 지원된다.

## 주의
- `CLAUDE_CODE_EFFORT_LEVEL` 환경변수가 설정돼 있으면 에이전트별 effort가 무시된다. 스크립트가 감지하면 경고한다.
- 모든 서브에이전트를 강제로 Opus에 고정하려면 `~/.claude/settings.json`의 env에 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE: "1"`을 추가할 수 있다. 단, 이 모드에서 에이전트별 effort가 유지되는지는 공식 문서에 명시되지 않았으므로 켠 뒤 `/tasks`로 확인한다.
