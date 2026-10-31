# Claude Code 운영 설정 (사람용 설명, 컨텍스트에 로드되지 않음)

프로젝트와 무관한 범용 묶음이다. `CLAUDE.md`, `.claude/`(agents, skills, hooks, settings.json), `scripts/` 세 가지를 어느 저장소에 복사해도 그대로 동작하고, 설치 스크립트를 한 번 실행하면 그 컴퓨터의 모든 Claude Code 세션에 적용된다. 이 저장소에만 해당하는 메모는 `.claude/rules/forcedimensions.md`에 경로 조건부로 따로 두었고 묶음에 포함되지 않는다.

## 구조
| 파일 | 역할 | 로드 시점 |
|---|---|---|
| `CLAUDE.md` | 운영 정책 코어: 메인 세션 = Architect, 서브에이전트 = 항상 Opus, 난이도는 effort 점수제, 승격·강등, 검증, 토큰 위생 | 매 세션 (서브에이전트에도 전달) |
| `.claude/agents/*.md` | Opus 에이전트 6종: `Explore`(탐색, low), `Plan`(계획 조사, high), `worker`(구현, medium), `verifier`(검증, high), `researcher`(조사, medium), `designer`(시각 산출물, high). Explore와 Plan은 같은 이름의 내장 에이전트를 덮어써 Opus로 고정한다 | 해당 에이전트를 띄울 때만 |
| `.claude/skills/delegate` | effort 판정 워크시트, 브리프 템플릿, 승격 사다리, 사용자 지시 해석, 예시 | 호출할 때만 (설명 한 줄만 상시) |
| `.claude/skills/skillify` | "스킬로 만들어줘" 절차 | 호출할 때만 |
| `.claude/skills/global-install` | "전역 적용해줘" 절차 | 호출할 때만 |
| `.claude/settings.json` | 서브에이전트 기본 모델 Opus, 자동 포크 끔, Agent 호출에 `model: "opus"`가 없으면 막는 PreToolUse 훅, 잡음 파일 읽기 차단 | 매 세션 |
| `.claude/hooks/require-opus.sh` | 위 훅의 스크립트. python3가 없으면 통과시킨다(fail-open) | Agent 호출마다 |
| `scripts/install-claude-global.{sh,ps1}` | 위 파일을 `~/.claude`에 설치해 모든 로컬 세션에 적용 | 수동 1회, 갱신 시 재실행 |

## 동작 원리 (공식 문서 기준, 2026-10 확인)
- 에이전트 파일의 `model: opus`와 `effort: <level>`은 독립된 설정이다. effort는 같은 모델의 추론 깊이만 바꾼다.
- Architect가 Agent 호출 시 넘기는 `effort` 값이 파일의 effort보다 우선한다(Claude Code 2.1.292 이상). `model` 별칭도 호출 시 값이 우선한다.
- `CLAUDE_CODE_EFFORT_LEVEL` 환경변수는 모든 effort 설정을 덮어쓴다. 절대 설정하지 않는다.
- `CLAUDE_CODE_SUBAGENT_MODEL=opus`는 모델이 지정되지 않은 서브에이전트의 기본값이다. 강제 고정용 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`은 그 모드에서 에이전트별 effort가 유지되는지 문서에 없어 쓰지 않았다.
- CLAUDE.md는 안내일 뿐 강제가 아니다(공식 문서). 그래서 "항상 Opus"는 세 겹으로 고정한다: 에이전트 파일의 `model: opus`, settings의 `CLAUDE_CODE_SUBAGENT_MODEL=opus`, 그리고 `model: "opus"` 없는 Agent 호출을 막는 PreToolUse 훅(막히면 Claude가 이유를 보고 다시 호출한다).
- Opus 5.5의 기본 effort는 medium, Fable 5.1은 high다.
- effort 판정은 점수제다. ① 범위 3파일 이상 ② 원인·방법 불명 ③ 런타임에서만 드러나는 실패 비용 ④ 트레이드오프 판단, 각 0/1점. 합계 0→low, 1→medium, 2→high, 3~4→xhigh. ③이 1이면 최소 high. "자동 검사 없음"은 effort가 아니라 검증 경로(verifier 필수)를 바꾼다.
- 포크(`/subtask`, 포크 모드)와 번들 스킬(`/code-review` 등)은 메인 모델로 돌기 때문에 "서브에이전트는 항상 Opus"에서 벗어난다. 그래서 `CLAUDE_CODE_FORK_SUBAGENT=0`으로 자동 포크를 끄고, 리뷰는 verifier 에이전트로 한다. `/subtask`를 직접 치면 여전히 포크가 뜬다(메인 모델).
- worker, verifier, researcher, designer는 `disallowedTools: Agent`로 중첩 위임이 막혀 있다. Explore와 Plan은 Read, Grep, Glob만 쓸 수 있어 읽기 전용이 하네스 수준에서 보장된다.
- 사용자 레벨 `~/.claude/CLAUDE.md`는 이 컴퓨터의 모든 프로젝트에 로드된다. 전역 설치는 이 저장소의 CLAUDE.md를 그 파일 안의 마커 블록으로 병합하는 방식이라 사용자의 기존 내용은 보존된다.
- 정책이 사용자 레벨과 프로젝트 양쪽에 있으면 이 저장소에서 두 번 로드되므로, 설치 스크립트가 저장소 쪽 CLAUDE.md 절대 경로를 `claudeMdExcludes`에 넣는다. 그 결과 이 컴퓨터에서는 전역 사본이 쓰이므로, 정책이나 스킬을 고치거나 pull한 뒤에는 설치 스크립트를 다시 실행해야 한다.
- 프로젝트 CLAUDE.md는 서브에이전트에도 전달된다. 그래서 정책은 핵심 구조만 담은 코어로 유지하고 긴 절차는 delegate 스킬(호출 시에만 로드)에 둔다. 커스텀 Explore의 `omitClaudeMd`는 CLAUDE.md를 제외한다(문서 확인).
- 다른 저장소의 클라우드 세션에는 전역 설치가 미치지 않는다. 그 저장소에 이 묶음을 커밋하거나, 클라우드 환경의 setup 스크립트에서 설정 저장소를 클론해 설치 스크립트를 실행해야 한다.

## 자주 쓰는 확인 명령
- `/context` 로드된 메모리 파일과 컨텍스트 사용량
- `/tasks` 실행 중인 서브에이전트의 모델과 effort
- `/usage` (별칭 `/cost`) 스킬, 서브에이전트, 플러그인별 사용량과 effort 권고
- `/effort status` 메인 세션 effort
- `/doctor prompt-audit` CLAUDE.md와 규칙의 오래된 항목, 모순 검사
- `claude plugin validate .claude/agents` 에이전트 파일 문법 검사 (오타는 조용히 무시되므로 수정 후 꼭 실행)

## 버전 요구
- 호출 시 effort 지정: Claude Code 2.1.292 이상. 그 아래에서는 에이전트 파일의 effort 기본값만 적용된다.
- `omitClaudeMd`: 2.1.271 이상. `CLAUDE_CODE_SUBAGENT_MODEL`이 프런트매터보다 낮은 우선순위로 바뀐 것: 2.1.251. 낮은 버전이면 `claude update`.

## 사용자 오버라이드 문구
- "effort high로 해줘" / "xhigh로" : 그 요청의 주 실행 에이전트 effort 지정
- "직접 해" : 위임 없이 Architect가 수행
- "위임해" : 강제 위임
- "스킬로 만들어줘" : skillify
- "전역 적용해줘" : global-install
- 프롬프트에 `ultrathink` : 그 턴만 깊은 추론

## 디자인·문서 스킬 설치 (선택, 로컬)
```
/plugin marketplace add anthropics/skills
/plugin install document-skills@anthropic-agent-skills
/plugin install example-skills@anthropic-agent-skills
```
두 번째 줄이 docx, pdf, pptx, xlsx(공식 확인). 세 번째 줄은 예시 스킬 묶음이며 정확한 목록은 설치 후 `/skills`에서 확인한다. 플러그인 스킬은 `document-skills:pptx`처럼 네임스페이스가 붙으므로 에이전트들은 목록에서 이름을 찾아 호출하도록 돼 있다.

## 전용 설정 저장소로 옮기기
새 저장소(예: `claude-config`)를 만들고 `CLAUDE.md`, `.claude/`(rules/ 제외), `scripts/`를 복사한 뒤 그 저장소에서 설치 스크립트를 실행하면 된다. 설치 스크립트는 자기 위치를 기준으로 파일을 찾는다.
