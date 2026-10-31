<!--
항상 로드되는 프로젝트 메모. 200줄 이하 유지.
운영 정책(Architect + Opus effort 라우팅)은 .claude/rules/routing.md 에 있고 같은 우선순위로 자동 로드된다.
-->
# ForceDimensions (SOFA 햅틱 플러그인)

## 빌드와 검증
- SOFA 소스 트리 안에서만 빌드된다. cmake에서 `SOFA_EXTERNAL_DIRECTORIES`에 이 경로를 추가하고 `FORCEDIMENSIONS_SDK_PATH`를 Force Dimension SDK 경로로 지정한다.
- 클라우드 세션과 SOFA가 없는 로컬에서는 컴파일할 수 없다. 검증은 diff 리뷰(medium 이상은 verifier)와 사용자 로컬 빌드로 한다. 코드 변경 보고에는 항상 "빌드 미확인"과 로컬 빌드 요청을 붙인다.
- 자동 테스트가 없다. 동작 확인은 `scenes/*.scn`을 runSofa로 실행하는 수동 절차다.
- `SOFASocketSender`는 Windows 전용이다(winsock2, ws2_32). Linux 빌드에서는 이 파일이 깨진다. 알려진 제약이므로 수정 요청이 없으면 건드리지 않는다.

## 코드 불변 조건 (바꾸려면 사용자 승인)
수정이 아래 조건을 바꿔야 하면 worker는 `ESCALATE: 불변 조건 변경 필요 <항목, 근거>`로 멈추고, Architect는 근거와 대안을 사용자에게 묻는다.
- 장치 초기화는 첫 animation step(Play 버튼)에서 한다. `init()`에서 열지 않는다.
- 햅틱 스레드는 `dhdStartThread` 콜백이며 `active`와 `shouldStop` 플래그로만 제어한다. 소멸자 순서: active=false → shouldStop=true → dhdSleep → dhdClose.
- `firstStepDone` 이전에는 힘 계산을 하지 않는다. LCP 초기화 전에 호출하면 크래시한다.
- 좌표 매핑 `Vec3(y, -x, z)`와 힘 전송 `dhdSetForce(f[2], f[0], f[1])`의 축 순서는 고정이다.
- `dhdOpen`을 쓴다. `drdOpen`과 DRD 의존성은 의도적으로 제거됐다. 다시 넣지 않는다.
- 임베디드 씬은 GL 컨텍스트가 없으므로 `OglModel` 대신 `VisualModelImpl`을 쓴다.
- 버전 문자열이 어긋나 있다. CMake는 0.2, `initForceDimensions.cpp`는 "0.1". 올릴 때는 둘 다 바꾼다.

## 관례
- 커밋 메시지는 영어, 기존 형식 유지(`Fix ...`, `feat: ...`). 주석은 한글과 영어 혼용을 허용한다.
- 세션에 지정된 작업 브랜치 외에는 push하지 않는다. PR은 요청이 있을 때만 만든다.

# Compact instructions
압축 시 유지: 현재 작업 목표, 배정한 effort와 승격 이력, 변경 파일 목록, 마지막 검증 명령과 결과, 열린 질문. 버릴 것: 파일 본문, 중간 서술, 해결된 오류 로그.
