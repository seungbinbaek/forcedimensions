---
paths:
  - "src/**"
  - "scenes/**"
  - "CMakeLists.txt"
---
<!-- 이 저장소(SOFA ForceDimensions 플러그인) 전용 메모. 위 경로의 파일을 읽거나 고칠 때만 로드된다. 범용 운영 정책 묶음에는 포함하지 않는다. -->
# ForceDimensions 프로젝트 메모

## 빌드와 검증
- SOFA 소스 트리 안에서만 빌드된다. cmake에서 `SOFA_EXTERNAL_DIRECTORIES`에 이 경로를 추가하고 `FORCEDIMENSIONS_SDK_PATH`를 Force Dimension SDK 경로로 지정한다.
- 클라우드 세션과 SOFA가 없는 로컬에서는 컴파일할 수 없다. 코드 변경 보고에는 "빌드 미확인"과 로컬 빌드 요청을 붙인다. 자동 테스트가 없고, 동작 확인은 `scenes/*.scn`을 runSofa로 실행하는 수동 절차다.
- `SOFASocketSender`는 Windows 전용이다(winsock2, ws2_32). 수정 요청이 없으면 건드리지 않는다.

## 코드 불변 조건 (바꾸려면 사용자 승인. worker는 `ESCALATE: 불변 조건 변경 필요 <항목, 근거>`로 멈춘다)
- 장치 초기화는 첫 animation step(Play 버튼)에서 한다. `init()`에서 열지 않는다.
- 햅틱 스레드는 `dhdStartThread` 콜백이며 `active`와 `shouldStop` 플래그로만 제어한다. 소멸자 순서: active=false → shouldStop=true → dhdSleep → dhdClose.
- `firstStepDone` 이전에는 힘 계산을 하지 않는다. LCP 초기화 전에 호출하면 크래시한다.
- 좌표 매핑 `Vec3(y, -x, z)`와 힘 전송 `dhdSetForce(f[2], f[0], f[1])`의 축 순서는 고정이다.
- `dhdOpen`을 쓴다. `drdOpen`과 DRD 의존성은 의도적으로 제거됐다.
- 임베디드 씬은 `OglModel` 대신 `VisualModelImpl`을 쓴다.
- 버전 문자열: CMake 0.2, `initForceDimensions.cpp` "0.1". 올릴 때는 둘 다.

## 관례
커밋 메시지는 영어, 기존 형식 유지(`Fix ...`, `feat: ...`). 세션에 지정된 작업 브랜치 외에는 push하지 않는다.
