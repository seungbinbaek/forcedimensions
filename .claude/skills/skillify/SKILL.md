---
name: skillify
description: 현재 세션에서 한 작업이나 반복 절차를 재사용 가능한 Claude 스킬(SKILL.md)로 저장하고 패키징하고 배포 준비까지 한다. 사용자가 "스킬로 만들어줘", "이거 스킬로 저장", "다음에도 똑같이 하게 해줘"라고 할 때 사용.
---
# skillify: 세션 결과물을 스킬로

목표: 대화에서 검증된 절차를 한 번의 요청으로 스킬 파일로 만들고, 로컬 전역과 프로젝트에 저장하고, 업로드용 패키지를 만든다. 설계(무엇을 스킬로 만들지, 발동 조건)는 Architect가 정하고, 파일 작성과 검증과 패키징은 worker(effort low~medium)에 위임한다. 브리프에 "`.claude/skills/<이름>/` 쓰기 허용"을 명시한다(CLAUDE.md §2의 settings·agents 수정 결정권은 Architect에게 있고, 내용을 정한 뒤 작성은 위임할 수 있다).

## 절차
1. **의도 추출**: 대화 기록에서 사용한 도구, 단계 순서, 사용자가 고쳐준 내용, 입출력 형식을 뽑는다. 빈 곳만 사용자에게 묻는다. 공식 `skill-creator` 스킬이 설치돼 있으면 Skill 도구로 호출해 그 절차를 따른다(대화 캡처 → 초안 → 검증 → 설명 최적화 → 패키징).
2. **이름과 발동 조건**: 이름은 소문자와 하이픈. description에는 "무엇을 하는지"와 "언제 쓰는지"(사용자가 실제로 칠 문장 예)를 함께 적는다.
3. **파일 작성**: `<이름>/SKILL.md` 본문은 절차, 입력, 출력 형식, 금지 사항 순서. 긴 참고 자료는 `references/`, 스크립트는 `scripts/`에 둔다.
   - claude.ai 업로드 가능성이 있으면 frontmatter를 `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`만 쓴다. 다른 키는 업로드 시 오류가 난다. Claude Code 전용이면 `model`, `effort`, `context: fork`, `disable-model-invocation` 등을 써도 된다.
4. **저장 위치**:
   - 프로젝트: `.claude/skills/<이름>/` (저장소와 함께 이동, 클라우드 세션에도 적용)
   - 로컬 전역: `~/.claude/skills/<이름>/` (이 컴퓨터의 모든 세션). 사용자가 "전역", "모든 세션"이라고 했을 때만. 클라우드 세션(`CLAUDE_CODE_REMOTE=true`)에서는 건너뛰고 보고에 적는다.
   - 기본은 프로젝트에만 저장한다.
5. **검증**: skill-creator가 있으면 `scripts/quick_validate.py`, 없으면 frontmatter에 name과 description이 있고 `---`가 첫 줄인지 확인한다. 가능하면 `/skills` 목록에 뜨는지 다음 세션에서 확인하라고 안내한다.
6. **패키징**: `dist/<이름>.skill`(zip)을 만든다. skill-creator의 `package_skill.py`가 있으면 그걸 쓰고, 없으면 `zip -r`로 만든다. `dist/`는 .gitignore에 있다.
7. **배포 준비**:
   - 스킬 저장소가 있으면(`~/claude-skills` 또는 사용자가 지정한 경로) 복사해 커밋한다. push는 사용자가 "push까지"라고 했을 때만.
   - claude.ai: 설정 → Capabilities → Skills에서 `.skill` 파일 업로드. 터미널에서 올리는 경로는 없다. 올리면 Claude Code 세션에 자동 동기화된다.
   - 다른 컴퓨터: 폴더를 `~/.claude/skills/`에 복사하는 것이 가장 단순하다. `/plugin marketplace add <계정/저장소>`로 설치하려면 저장소에 `.claude-plugin/marketplace.json`과 플러그인별 `.claude-plugin/plugin.json`이 있어야 한다(공식 plugin-marketplaces 문서 참고). 사용자가 원하면 그 구조를 함께 만든다.

## 보고 형식
저장 경로(프로젝트, 전역) / 패키지 경로 / 검증 결과 / 업로드 방법 한 줄 / 사용자가 확인할 것(새 세션에서 `/skills`).
