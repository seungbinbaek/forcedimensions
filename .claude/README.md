# Claude Code 운영 설정 (사람용 설명, 컨텍스트에 로드되지 않음)

## 구조
| 파일 | 역할 | 로드 시점 |
|---|---|---|
| `CLAUDE.md` | 이 프로젝트 메모(빌드, 불변 조건, 관례) | 매 세션 |
| `.claude/rules/routing.md` | 운영 정책: 메인 세션 = Architect, 서브에이전트 = 항상 Opus, 난이도는 effort로 | 매 세션 (CLAUDE.md와 같은 우선순위) |
| `.claude/agents/*.md` | Opus 에이전트 5종: `Explore`(탐색, low), `worker`(구현, medium), `verifier`(검증, high), `researcher`(조사, medium), `designer`(시각 산출물, high) | 해당 에이전트를 띄울 때만 |
| `.claude/skills/delegate` | 브리프 템플릿, effort 판정 워크시트, 승격 사다리 | 호출할 때만 (설명 한 줄만 상시) |
| `.claude/skills/skillify` | "스킬로 만들어줘" 절차 | 호출할 때만 |
| `.claude/skills/global-install` | "전역 적용해줘" 절차 | 호출할 때만 |
| `.claude/settings.json` | 서브에이전트 기본 모델 Opus, 잡음 파일 읽기 차단 | 매 세션 |
| `scripts/install-claude-global.*` | 위 파일을 `~/.claude`에 복사해 모든 로컬 세션에 적용 | 수동 1회 |

## 동작 원리 (공식 문서 기준, 2026-10 확인)
- 에이전트 파일의 `model: opus`와 `effort: <level>`은 독립된 설정이다. effort는 같은 모델의 추론 깊이만 바꾼다.
- Architect가 Agent 호출 시 넘기는 `effort` 값이 파일의 effort보다 우선한다(Claude Code 2.1.292 이상). `model` 별칭도 호출 시 값이 우선한다.
- `CLAUDE_CODE_EFFORT_LEVEL` 환경변수는 모든 effort 설정을 덮어쓴다. 절대 설정하지 않는다.
- `CLAUDE_CODE_SUBAGENT_MODEL=opus`는 모델이 지정되지 않은 서브에이전트의 기본값이다. 강제 고정이 필요하면 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`을 추가할 수 있지만, 그 모드에서 에이전트별 effort가 유지되는지는 문서에 없으므로 `/tasks`로 확인 후 사용한다.
- Opus 5.5의 기본 effort는 medium, Fable 5.1은 high다.
- 사용자 레벨 `~/.claude/rules/*.md`(paths 없음)는 이 컴퓨터의 모든 프로젝트에 로드된다. 그래서 전역 설치는 `routing.md`를 그 위치로 복사하는 방식이다.
- `routing.md`가 사용자 레벨과 프로젝트 양쪽에 있으면 이 저장소에서 두 번 로드되므로, 설치 스크립트가 저장소 쪽 절대 경로를 `claudeMdExcludes`에 넣는다.

## 자주 쓰는 확인 명령
- `/context` 로드된 메모리 파일과 컨텍스트 사용량
- `/tasks` 실행 중인 서브에이전트의 모델과 effort
- `/usage` (별칭 `/cost`) 스킬, 서브에이전트, 플러그인별 사용량과 effort 권고
- `/effort status` 메인 세션 effort
- `/doctor prompt-audit` CLAUDE.md와 규칙의 오래된 항목, 모순 검사
- `claude plugin validate .claude/agents` 에이전트 파일 문법 검사 (오타는 조용히 무시되므로 수정 후 꼭 실행)

## 사용자 오버라이드 문구
- "effort high로 해줘" / "xhigh로" : 그 요청의 위임 effort 지정
- "직접 해" : 위임 없이 Architect가 수행
- "위임해" : 강제 위임
- "스킬로 만들어줘" : skillify
- "전역 적용해줘" : global-install
- 프롬프트에 `ultrathink` : 그 턴만 깊은 추론

## 디자인 스킬 설치 (선택, 로컬)
```
/plugin marketplace add anthropics/skills
/plugin install document-skills@anthropic-agent-skills
/plugin install example-skills@anthropic-agent-skills
```
두 번째 줄이 pptx, docx, pdf, xlsx, 세 번째 줄이 theme-factory, frontend-design, canvas-design, skill-creator 등이다. 클라우드 세션에는 문서 스킬이 이미 동기화돼 있다.
