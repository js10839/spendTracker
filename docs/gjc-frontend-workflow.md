# GJC를 이용한 Flutter 프론트엔드 작업 가이드

Gajae-Code(`gjc`)는 Flutter 화면 구현을 AI에 맡길 때 사용한다. 제품·API 계약과 리뷰 책임은 사람이 유지하고, 처음에는 화면 하나의 계획과 구현으로 사용 범위를 확인한다. Flutter 프로젝트는 `frontend/`에 있다.

## 시작 전

1. 프론트엔드 작업은 공통 작업용 `colinsung` 브랜치와 분리된 기능 브랜치에서 진행한다. 작업 전 원격 변경사항과 작업 트리 상태를 확인한다.
2. 저장소 루트에서 `gjc`를 실행하고, 첫 세션에서 `/login`으로 사용할 코딩 플랜을 선택한다.
3. `Spending-tracker.md`를 제품 명세로 지정한다. 현재 루트 `AGENTS.md`는 Git에서 제외되어 있으므로 다른 팀원이나 새 worktree에는 자동으로 전달되지 않는다. 중요한 작업 규칙은 첫 요청에도 명시한다.
4. 화면 구현은 `frontend/lib/`에서 시작한다. 앱 구조는 첫 기능의 책임이 분명해질 때 필요한 만큼 확장한다.

처음부터 MCP, 추가 스킬, 자동 실행 설정을 구성할 필요는 없다. GJC의 프로젝트별 `.gjc/` 설정도 현재 `.gitignore`에 포함되어 있어 팀에 자동 공유되지 않는다.

## 첫 작업 범위

첫 후보는 **내 지갑 → 카드 추가** 화면이다. 백엔드에는 결제수단 생성 API가 있으므로 한 화면에서 입력 상태, 검증, API 연결, 결과 표시까지 확인할 수 있다. 목록 조회처럼 아직 구현되지 않은 API가 필요하면 임의로 계약을 만들지 말고 먼저 확인한다.

구현 전에 GJC의 `deep-interview` 또는 `ralplan`으로 화면 상태, 파일 위치, API 계약, 검증 방법을 정리한다. 계획을 검토한 다음에만 구현을 맡긴다. 첫 화면이 완료되면 작은 화면과 세로로 긴 화면의 overflow, 로딩·실패 상태, 실제 백엔드 응답과의 일치 여부를 확인한다.

첫 요청 예시:

```text
Spending-tracker.md를 읽고 Flutter의 '내 지갑 → 카드 추가' 화면을 계획해줘.
Flutter 프로젝트는 frontend/에 있어. 기존 앱 구조를 읽고 필요한 범위만 수정해줘.
AGENTS.md의 프로젝트 규칙을 읽되, 새 worktree에 파일이 없으면 아래 규칙을 적용해:
- 앱 데이터의 읽기·쓰기는 FastAPI를 통한다. Flutter가 Supabase에 직접 접근하는 것은 Auth뿐이다.
- 사용자에게는 '내 지갑', '카드 추가'를 쓰고 코드에서는 payment_method를 쓴다.
- compact/tall 모바일 화면에서 overflow를 확인한다.
- 시크릿이나 실제 영수증 데이터를 출력하거나 커밋하지 않는다.
먼저 화면 상태, 필요한 API, 파일 배치, 검증 방법을 제시해줘.
내가 계획을 확인하기 전에는 파일 수정·패키지 설치·커밋·푸시를 하지 마.
```

구현 후에는 변경 diff와 테스트 결과를 사람이 확인하고 PR로 검토한다. GJC가 생성한 코드라도 화면 동작과 API 계약의 최종 결정은 팀이 한다.

## 참고 자료

- [Gajae-Code 빠른 시작과 워크플로](https://github.com/Yeachan-Heo/gajae-code/blob/main/README.ko.md)
- [Gajae-Code 프로젝트 설정 범위](https://github.com/Yeachan-Heo/gajae-code/blob/main/docs/customization.md)
