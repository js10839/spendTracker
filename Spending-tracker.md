# Money Spending Tracker — MVP 계획서

## 0. 배경 — 기존 가계부 앱의 한계

본 프로젝트는 기존 지출 관리 앱들이 해결하지 못하는 두 가지 문제에서 출발한다. (실사용 중 직접 확인한 한계이며, 개발자 본인이 첫 사용자로서 검증 루프가 가장 짧다.)

- **집계 기준의 한계**: 시중 가계부는 예외 없이 달력 월(1일~말일) 기준으로 지출을 집계한다. 그러나 신용카드 사용자의 실제 관심사인 "이번 카드값"은 statement closing date 기준으로 확정된다 (예: closing date가 21일이면 실제 청구 단위는 전월 22일~당월 21일). 이 불일치 때문에 사용자는 가계부를 쓰면서도 카드값 예측을 위해 매번 수동 계산을 해야 한다 — 도구가 가장 중요한 질문에 답하지 못하는 구조적 공백.

- **입력 방식의 한계**: 거래 단위 기록만 지원하는 기존 앱에서 품목 수준 데이터를 남기려면 메모란에 수동 타이핑해야 한다. 현실적으로 사용자는 "장보기 $52"로 뭉뚱그리게 되고, 카테고리별 지출 분석의 정밀도는 상점 단위에서 멈춘다.

이 두 한계가 각각 본 제품의 핵심 기능 1번(closing date 기준 사이클 추적)과 3번(영수증 AI 파싱을 통한 품목 단위 자동 기록)으로 이어진다.

## 0.1 시장 조사 (2026.08 기준)

**결론: 개별 기능의 경쟁자는 있으나, 조합은 비어 있다.**

| 진영 | 대표 | 하는 것 | 안 하는 것 |
|---|---|---|---|
| 영수증 품목 파싱 앱 | keepm, Skwad, Grocery Tracker, Itemize AI 등 | AI로 품목별 추출·카테고리 분류 (2025년 이후 다수 등장 — **파싱만으로는 차별점 불가**) | 사이클 개념 없음 — 전부 달력 월 기준 |
| 카드 사이클 뷰어 | CardCycle, CrediVitals | Plaid 은행 연동으로 여러 카드의 잔액·due date 통합 표시 | 은행 기록의 조회·표시에 한정 — 지출 기록·품목 데이터 없음 |
| 카드 혜택 최적화 | CardPointers, StackEasy | 카드별 크레딧·보너스 마감 추적 | 지출 추적 자체가 목적이 아님 |
| 가계부 메이저 | YNAB, Copilot, Monarch 등 | 은행 연동 + 예산 | 달력 월 고정, 품목 파싱 없음, 연동 필수라 무거움 |

- **수요 신호**: 커뮤니티에서 사용자들이 카드별 billing cycle을 탭으로 나눈 엑셀을 직접 제작해 공유 중 — 제품이 없어서 스프레드시트로 버티는 전형적 공백 신호. "카드 여러 장의 사이클이 제각각이라 월말 숫자가 머릿속과 안 맞는다(statement-cycle confusion)"는 문제가 커뮤니티에서 명명되어 있음.

- **포지셔닝 시사점**: 홍보 리드는 파싱이 아니라 **사이클** — "카드값이 얼마 나올지 마감 전에 아는 앱". 파싱은 "입력이 편한 이유"로 뒤에 배치. 파싱을 앞세우면 붐비는 영수증 앱 시장에 묻힘.

- **경쟁 앱 리뷰·릴리즈 노트에서 배운 것** (설계 요구사항으로 반영):

- 할인/쿠폰 라인(음수 금액) 처리 실패 → 합계 불일치가 주요 불만 → 파싱 프롬프트에 음수 라인 처리 명시 + total 검증 배지 (기설계)

- 영수증 축약 표기("WHL MLK 2% 1G")가 그대로 저장되는 불만 → 프롬프트에 품목명 정규화(읽기 좋게 풀어 쓰기) 명시

- "무료 3회 후 월 $9.99" 식 공격적 페이월에 대한 반감 → 본 제품의 넉넉한 무료 티어 + 한도 초과 시에도 수동 입력 가능한 설계가 차별점

- 데이터 판매 불신이 카테고리 기본 정서 → 개인정보 처리 범위와 삭제 정책을 검증한 뒤 투명하게 설명하는 것이 신뢰 포인트

- 상위 앱들도 실측 정확도 92~94% (100%는 불가) → 확인 화면 = 필수 안전망 재확인

- **리스크**: 이 조합이 비어 있는 이유가 "아무도 안 해서"인지 "수요가 작아서"인지는 미검증 — 학기 프로젝트 + 캠퍼스 소프트런칭 규모가 검증에 적합.

---

## 1. 제품 개요

**한 줄 요약**: 신용카드 결제 사이클 기준으로 지출을 추적하고, 영수증 사진을 AI로 파싱해 자동 기록하는 iOS·Android 지출 관리 앱.

**앱 이름 방향 (2026-10-17 미팅)**: 팀은 **다다리**를 후보로 사용하기로 했다. 공식 영문 표기와 최종 로고 에셋은 아직 확정하지 않았으므로 저장소명과 기존 자산은 유지한다.

**타겟 사용자**: 신용카드를 주로 쓰면서 "이번 카드값이 얼마나 나올지"를 실시간으로 알고 싶은 사람.

**플랫폼 전략**: **Flutter 기반 iOS + Android 모바일 앱**

- Flutter 단일 코드베이스로 iOS·Android 동시 지원

- 영수증 촬영·갤러리 선택 등 모바일 네이티브 기능을 직접 활용

- 초기 MVP는 웹 버전 없이 모바일 앱에 집중

- 푸시 알림·홈 위젯 등 모바일 기능은 우선순위에 따라 단계적으로 추가

- 앱 배포는 TestFlight / Android 테스트 트랙을 거쳐 App Store·Google Play 출시 목표

**핵심 차별점**:

1. 카드별 결제 사이클 기준 지출 측정 (기존 앱은 대부분 매월 1일 고정)

2. 신용카드 지출 vs 현금성 지출(debit, cash, Zelle 등) 명확한 구분

3. 영수증/거래내역 이미지 업로드 → AI 파싱 → 품목별 자동 카테고리 분류

4. (Post-MVP) 공유 가계부 — 커플/룸메이트용 + 가상 모임통장 (기록·잔액 추적만, 실제 돈 보관은 안 함)

---

## 2. 범위 (Scope)

### Phase 1 — Core (MVP 필수)

- [ ] 결제수단 등록: 신용카드(statement closing date 지정) / 현금성 수단 — 카드별 색상 지정

- [ ] 지출 수동 입력: 금액, 카테고리, 결제수단, 날짜, 메모

- [ ] 카드별 사이클 뷰: 현재 사이클 지출 합계, 남은 일수, 진행률

- [ ] 통합 대시보드: 최근 30일 전체 지출, 카드 vs 현금 비율, 카테고리별 분포

- [ ] 카테고리 목록 조회 (운영팀이 정한 기본 12개 제공: Food, Living, Electronics, Fashion, Dining, Transport, Subscription, Utilities·Bills, Health, Entertainment, Travel, Etc). 사용자는 카테고리를 추가·수정·삭제하지 않는다.

### Phase 2 — 핵심 차별화 (Wow Factor)

- [ ] 영수증/스크린샷 업로드

- [ ] Vision LLM API로 파싱 → 품목/가격/추정 카테고리 JSON 추출

- [ ] 확인 화면: 사용자가 품목별 카테고리·가격 수정 후 일괄 저장

- [ ] 파싱 결과 개인화: 사용자가 수정한 분류를 merchant+품목 규칙으로 저장

### Phase 3 — Post-MVP (검증 후)

- [ ] 유료 플랜 (freemium): Pro 단일 플랜 — 카드 무제한 + 파싱 월 50장 ⚠️ 수치·가격 논의 중 (상세는 "회원 등급 구조" 참조)

- 모바일 구독 결제 연동: App Store / Google Play 인앱 결제 기반. Flutter 통합은 RevenueCat 등 공통 레이어 사용 여부를 출시 전 결정

- 가격 설계: 파싱 원가(장당 ~$0.005–0.02) 대비 마진 확인

- **결제는 회원만 가능** (비회원 결제 불가 — 구매 귀속·복구·환불을 user_id와 스토어 구매 정보에 연결)

- [ ] 공유 가계부 (커플/룸메이트용 + 가상 모임통장) — ledger에 멤버 초대, 홈에 ledger switcher 추가. **API는 처음부터 `/ledgers/{id}/...` 경로로 설계** (MVP 코딩 시점부터 적용, 나중에 switcher만 붙이면 됨)

- [ ] 정산 뷰 (누가 얼마 썼는지)

- [ ] **Pro 기능 — 캘린더 연동**: 카드 마감일·예상 카드값·반복 결제일을 Apple/Google 캘린더에 연동하는 기능 검토. 네이티브 푸시 알림과 역할을 구분해 필요성 검증 후 구현

- [ ] 환불/취소 처리, 반복 지출(구독) 지원

- [ ] 네이티브 확장 기능 — 푸시 알림("카드 마감 D-3"), 홈 위젯, 딥링크 등은 MVP 이후 우선순위에 따라 추가

### 회원 등급 구조 ⚠️ 논의 중 — 미확정

> 아래는 현재 유력한 안이며 MVP 검증 전까지 확정하지 않음. 특히 카드 개수 제한 수치와 Pro 가격은 실사용 데이터 확인 후 결정.

| 등급 | 데이터 저장 | 카드 개수 | 파싱 한도 | 비고 |
|---|---|---|---|---|
| 비회원 (체험) | 기기 로컬 저장소(SQLite) | 1개 | 총 3장 | 앱 삭제·기기 변경 시 소실 가능 경고, "가입하면 기록 저장" 전환 유도 |
| 무료 회원 | 서버 | 2개 | 월 10장 | 이메일 인증 필수 (어뷰징 방지) |
| Pro (단일 유료) | 서버 | 무제한 | 월 50장 | 3티어(실버/골드/다이아) 대신 단일 플랜으로 시작 — 선택지 축소로 전환율 확보, 운영 단순화 |

**파싱 한도 리셋 원칙** ✅ 확정: 월 한도는 매월 1일 리셋, **잔여분 이월 없음, 저장형 크레딧 없음** (무료·Pro 동일). quota 로직이 "이번 달 receipts COUNT" 하나로 유지되는 근거.

**Post-MVP 확장 방향 (미확정)**:

- 파싱 추가 구매: 한도 초과 유저 대상 일회성 크레딧 팩 (예: +20장) — 티어 신설보다 가벼움 (카운터 증가 + 일회성 결제). "50장 소진 유저 비율" 지표 확인 후 가격 결정

- 공유 가계부 출시 시: Pro 한도 100장 상향 or "멤버 수 × 50장" 규칙 검토 (2인 사용 시 파싱 수요 ~2배 가정)

- 비회원 → 회원 전환 시 **기기 로컬 데이터 → 서버 마이그레이션** 제공 (전환율 핵심 장치)

- 비회원 무료 한도는 앱 데이터 초기화·재설치 등으로 우회 가능하므로 보수적으로 낮게 설정하고 방어 로직에 과투자하지 않음

- **비회원 데이터 정책**: 일반 지출 데이터는 기기 로컬 저장소(SQLite)에만 저장 — 서버 DB에 기록 없음. 영수증 파싱 시에만 이미지가 서버를 경유하며, **파싱 완료 즉시 이미지 삭제** (결과 텍스트만 앱에 반환, 서버에 잔존물 없음). 앱 삭제·기기 변경 시 데이터가 소실될 수 있음을 명확히 안내

### Out of Scope (MVP에서 제외)

- 은행/카드사 API 연동 (Plaid 등) — 비용·심사 이슈

- 예산 기능, 웹 버전, 다국어

---

## 3. 기술 스택

| 레이어 | 선택 | 이유 |
|---|---|---|
| Backend | Python + FastAPI | 핵심 비즈니스 로직, 인증 검증, DB 접근, 외부 API 연동을 한 곳에서 관리 |
| Mobile App | Flutter (Dart), iOS + Android | 단일 코드베이스로 양 플랫폼 지원, 카메라·갤러리·푸시 등 모바일 기능 확장 용이 |
| DB | Supabase Managed PostgreSQL | 표준 PostgreSQL 사용. Flutter가 직접 DB에 접근하지 않고 FastAPI → SQLAlchemy를 통해서만 Read / Write |
| 인증 | Supabase Auth — Email/Password + Email Verification + Guest | 비밀번호 해싱·세션·토큰·이메일 인증은 Supabase Auth가 담당. Google/Apple 로그인은 필요 시 추가 |
| 인증 이메일 | Resend 등 Transactional Email Provider + 앱 도메인 | Production 인증 메일 발송용. Supabase Auth와 custom SMTP로 연결 |
| 모바일 결제 | App Store / Google Play IAP, RevenueCat 검토 | Pro 구독의 구매·복구·entitlement를 양 플랫폼에서 일관되게 관리. 유료화 전 최종 확정 |
| 이미지 스토리지 | Supabase Storage (private bucket, 도입 검토) | 영수증 원본은 영구 보관하지 않는다. 파싱 중 임시 저장이 필요한지와 삭제 시점은 구현 전 확정 |
| 스토리지 확장 경로 | Cloudflare R2 / S3 | Storage wrapper 뒤에 격리해 추후 교체 가능 |
| ORM / Migration | SQLAlchemy + Alembic | Supabase 전용 DB API 대신 표준 PostgreSQL 접근. Migration을 코드로 관리 |
| 영수증 파싱 | Google Gemini Vision API | 영수증 이미지 → structured output. Gemini 연결은 공통 integration, 파싱 규칙은 Receipt Service가 소유 |
| 배포 | Backend: Railway/Render, App: TestFlight + Google Play 테스트 트랙 | 모바일 앱은 스토어 배포 플로우 사용 |

**Supabase 사용 원칙**: Supabase Auth와 PostgreSQL을 사용한다. 파싱 중 임시 저장이 필요한 경우 Storage 도입을 검토하되, Supabase 전용 코드를 앱 전체에 퍼뜨리지 않는다. 핵심 비즈니스 로직은 FastAPI에 두고 provider-specific 코드는 Auth / Storage / Integration 경계에 격리한다.

**이미지 접근 보안**: 영수증은 구매 내역이 담긴 민감 정보다. 임시 Storage를 사용한다면 private bucket으로 제한하고 앱이 직접 Read / Write하지 않으며, FastAPI에서 권한을 확인한다. 영구 이미지 보관이나 원본 재열람 기능은 제공하지 않는 방향이다.

### 3.1 인증 아키텍처 결정

1. **Email/Password + Email Verification** ✅: 현재 MVP는 이메일과 비밀번호를 받고 이메일 인증을 완료한 뒤 계정을 활성화하는 방향. 비밀번호 해싱과 credential 저장은 Supabase Auth가 담당하며 `public.users`에는 비밀번호 관련 컬럼을 두지 않는다.

2. **Guest 모드** ✅: 계정 없이 앱을 사용할 수 있다. Guest 데이터는 Flutter 기기 로컬 SQLite에 저장하고, 회원 전환 시 서버로 마이그레이션한다.

3. **User ≠ Email** ✅: 앱 데이터의 실제 소유자는 Supabase Auth의 고유 UUID다. `public.users.id = auth.users.id` 형태로 연결하며 transaction / ledger 등 앱 데이터는 이메일을 FK로 사용하지 않는다.

4. **Social Login** ⚠️ 확장 가능: Google / Apple Sign-In은 Supabase Auth provider로 추가 가능하게 설계하되 MVP 포함 범위는 개발 일정에 따라 결정한다.

5. **Account Linking** ⚠️ Post-MVP 검토: Email / Google / Apple 계정을 자동 병합하지 않는다. 서로 다른 provider identity를 하나의 사용자로 연결하는 기능은 별도 요구사항으로 다룬다.

6. **인증 이메일 발송** ✅ 방향: Production에서는 Resend 같은 Transactional Email Provider를 Supabase custom SMTP에 연결한다. 인증 메일 요청에는 rate limit과 resend cooldown을 적용한다.

7. **Guest → 회원 전환** ✅: Guest 데이터는 인증 완료 후 해당 `user_id`의 서버 데이터로 이전한다. 중복 전송이나 재시도를 고려해 migration은 idempotent하게 설계한다.

8. **초기 표시 이름 (2026-10-17 미팅 방향)**: 가입 때 랜덤 표시 이름을 제안하고 사용자가 수정하거나 건너뛸 수 있게 한다. 이후 프로필에서도 변경할 수 있다. 이름 생성 규칙은 TBD이며, 현재 `public.users.nickname` 컬럼만 존재하고 관련 UI/API는 아직 구현되지 않았다.

### 3.2 Supabase 의존성 경계

1. **Database**: Supabase의 managed PostgreSQL을 사용하지만 모든 앱 데이터 Read / Write는 `Flutter → FastAPI → Service → Repository → SQLAlchemy → PostgreSQL` 경로를 따른다. Flutter에서 Supabase Database SDK를 직접 사용하지 않는다.

2. **Auth**: Flutter는 Supabase Auth SDK를 사용해 로그인할 수 있다. 로그인 후 발급된 JWT를 FastAPI에 전달하고, FastAPI의 공통 Auth dependency가 검증한다.

3. **App User Profile**: Supabase Auth의 `auth.users`는 credential / identity를 관리하고, 앱 전용 정보는 `public.users`에 저장한다. 두 테이블은 동일한 UUID로 1:1 연결한다.

4. **Storage (계획)**: 파싱 중 임시 저장이 필요하다면 Supabase Storage 호출을 FastAPI의 공통 Storage Service / Wrapper에 격리한다. 원본 영구 보관은 하지 않으며, 임시 처리·삭제 정책은 별도로 확정한다.

5. **External AI**: Gemini SDK / API key / timeout / retry는 `integrations/gemini.py` 같은 공통 client에서 관리한다. Prompt, category logic, total validation은 Receipt Service가 관리한다.

6. **Portability**: PostgreSQL은 표준 SQLAlchemy/Alembic으로 관리하고, Auth·Storage·Gemini 같은 provider-specific 코드는 경계 모듈에 모은다.

### 3.3 시스템 아키텍처 결정

1. **데이터 단일 경로** ✅: 읽기·쓰기 모두 FastAPI 경유. Flutter 앱이 Supabase와 직접 통신하는 것은 Auth뿐 — 로직(사이클·quota·멤버십 검사)이 한 곳에 모이고, RLS는 방어 계층으로 유지한다.

2. **이미지 업로드는 서버 경유** ✅: Flutter → FastAPI → 검증·재인코딩·EXIF 제거·리사이즈 → Gemini. 임시 Storage 사용 여부와 삭제 시점은 TBD이며 원본을 영구 보관하지 않는다.

3. **파싱은 확장 가능한 동기 처리** ✅: MVP는 동기 처리로 시작하되 API 계약은 추후 queue 기반 비동기 처리로 교체 가능하게 유지한다.

4. **임시 이미지 정리** ⚠️ 미확정 — 저장이 필요하다면 삭제 시점과 실패 시 정리 방법을 먼저 정한다. 이전의 "미저장 이미지 7일 보관" 가정은 원본 비보관 방향에 맞춰 재검토한다.

---

## 4. 데이터 모델 (현행 / 계획 구분)

**현행**: Alembic/SQLAlchemy에는 `users`, `ledgers`, `ledger_members`, `payment_methods`, `categories`, `transactions`가 있다. 아래 `receipts`, `categorization_rules`, `income_*`는 아직 구현되지 않은 계획이다. `transactions.receipt_id`도 현행 모델·마이그레이션에는 없다.

**핵심 원칙**

- Supabase Auth의 `auth.users`는 로그인 credential과 identity를 관리한다.
- 앱 전용 사용자 정보는 `public.users`에서 관리한다.
- `public.users.id`는 Supabase Auth의 `auth.users.id`와 동일한 UUID를 사용한다.
- 모든 금액은 달러 실수가 아니라 **cents 정수**로 저장한다.
- `transactions`는 지출 전용으로 유지하고, 수입은 `income_sources` + `income_records`로 분리한다.
- `income_sources`는 반복 수입 규칙, `income_records`는 실제로 들어온 수입 기록이다.

```text
auth.users                         # Supabase Auth가 관리
- id uuid PK
- email
- encrypted_password / identities / session metadata
# 앱 코드에서 비밀번호·OTP 등을 직접 저장하지 않음


public.users                       # 앱 전용 프로필
- id uuid PK, FK -> auth.users.id
- nickname text nullable
- plan text NOT NULL               # free | pro
- created_at timestamp
- updated_at timestamp


ledgers
- id uuid PK
- name text
- owner_user_id uuid FK -> users.id
- created_at timestamp
- updated_at timestamp


ledger_members                     # 테이블 현행, 공유 기능은 향후 확장
- ledger_id uuid FK -> ledgers.id
- user_id uuid FK -> users.id
- role text
- created_at timestamp
- UNIQUE (ledger_id, user_id)


payment_methods
- id uuid PK
- user_id uuid FK -> users.id     # 내 지갑은 사용자 소유, 가계부 전환과 무관
- name text
- type text                        # credit | cash-like
- closing_day int nullable         # credit만 1~31
- color text
- created_at timestamp
- updated_at timestamp


categories
- id uuid PK
- ledger_id uuid FK -> ledgers.id
- name text
- icon text nullable
- is_default bool
- description text                 # LLM 분류 기준
- created_at timestamp
- updated_at timestamp


transactions                       # 지출 전용
- id uuid PK
- ledger_id uuid FK -> ledgers.id
- payment_method_id uuid FK -> payment_methods.id
- category_id uuid FK -> categories.id
- receipt_id uuid nullable FK -> receipts.id  # Phase 2 계획, 현행 DB에는 없음
- amount_cents int NOT NULL
- currency text NOT NULL default 'USD'
- merchant text nullable
- memo text nullable
- transacted_at date NOT NULL
- source text                      # manual | receipt_parse
- created_at timestamp
- updated_at timestamp
- deleted_at timestamp nullable


receipts
- id uuid PK
- ledger_id uuid FK -> ledgers.id
- raw_parse_json jsonb
- status text                      # pending | draft | parsed | failed
- created_at timestamp
- updated_at timestamp
- deleted_at timestamp nullable


categorization_rules
- id uuid PK
- ledger_id uuid FK -> ledgers.id
- category_id uuid FK -> categories.id
- merchant text nullable
- item_keyword text nullable
- created_at timestamp
- updated_at timestamp


income_sources                     # 반복되는 수입 규칙
- id uuid PK
- ledger_id uuid FK -> ledgers.id
- name text NOT NULL               # Paycheck, Part-time Job 등
- income_type text NOT NULL        # salary | freelance | other 등
- expected_amount_cents int NOT NULL
- frequency text NOT NULL          # weekly | biweekly | monthly
- reference_date date NOT NULL     # 실제 수입 주기 계산 기준일
- next_expected_date date NOT NULL # Backend가 계산
- is_active bool NOT NULL default true
- created_at timestamp
- updated_at timestamp


income_records                     # 실제 수입 기록
- id uuid PK
- ledger_id uuid FK -> ledgers.id
- income_source_id uuid nullable FK -> income_sources.id
- name text NOT NULL               # 실제 기록 시점의 이름 snapshot
- income_type text NOT NULL        # salary | tip | cashback | freelance | other
- amount_cents int NOT NULL
- received_at date NOT NULL
- memo text nullable
- created_at timestamp
- updated_at timestamp
```

**날짜별 메모 (미구현·설계 TBD)**: 2026-10-17 미팅에서 날짜에 메모를 남기는 방향에 합의했다. 현행 `transactions.memo`는 개별 지출 메모이며 날짜 메모를 대체하지 않는다. 사용자 개인/가계부 중 소유 범위, 시간대, 같은 날짜의 복수 메모 허용 여부와 저장 구조는 미정이므로 여기서 새 테이블·컬럼을 확정하지 않는다. 영수증 원본 이미지는 영구 보관하지 않으며, `receipts`의 임시 이미지 참조 필요 여부도 TBD다.

### 4.0.1 Income 설계 원칙

- **정기 수입**: 먼저 `income_sources`에 규칙을 저장한다.
- `frequency`와 `reference_date`는 둘 다 **required / NOT NULL**.
- `next_expected_date`는 사용자가 입력하지 않고 FastAPI가 `frequency + reference_date`를 기준으로 계산한다.
- 실제 수입이 확인되면 `income_records`에 한 건을 생성한다.
- 실제 금액은 예상 금액과 다를 수 있으므로 `expected_amount_cents`와 `amount_cents`를 분리한다.
- **비정기 수입**(tip, cashback, 일회성 freelance 등)은 `income_source_id = NULL`로 `income_records`에 바로 저장할 수 있다.
- 수입 알림 시간은 사용자별 DB 설정으로 받지 않고 앱 정책으로 고정한다.
- Flutter는 `next_expected_date`를 받아 앱에서 정한 시간에 local notification을 예약한다.
- MVP에서는 별도 notification table을 만들지 않는다.

### 4.0.2 다음 수입일 계산 예시

```text
frequency = weekly
reference_date = 2026-10-16
→ next_expected_date = 2026-10-23

frequency = biweekly
reference_date = 2026-10-16
→ next_expected_date = 2026-10-30

frequency = monthly
reference_date = 2026-10-16
→ next_expected_date = 2026-11-16
```

월별 계산에서 다음 달에 같은 날짜가 없으면 해당 월의 마지막 날로 fallback하는 규칙을 사용한다.

**게이팅 구현 원칙 (⚠️ 등급 구조와 함께 미확정)**: 별도 카운터 테이블/컬럼 없이 파생 계산.

- 파싱 사용량 = `receipts`에서 `status IN ('draft','parsed') AND created_at >= 이번 달 1일` COUNT
- 카드 개수 = `payment_methods` COUNT
- 비회원 한도는 Flutter 기기 로컬 SQLite에서 카운트

**사이클 계산 원칙**: 기준은 **statement closing date**. DB에 카드 사이클 row를 저장하지 않고 `payment_methods.closing_day`를 기준으로 조회 시점에 계산한다.

`내 지갑`의 결제수단은 사용자에게 속하며 가계부를 바꿔도 같은 목록을 보여준다. 지출 기록은 선택한 가계부에 속하고, 그 사용자가 소유한 결제수단을 참조한다. 카드별 사이클의 여러 가계부 지출 집계 범위는 별도로 확정한다.

- 사이클 = 전월 closing date 다음날(포함) ~ 이번 closing date(포함). 월별 길이가 달라 29~31일이 없는 경우 아래 fallback을 먼저 적용한다.
- closing_day가 29~31인데 해당 월에 없으면 그 달 마지막 날로 fallback
- UI에서는 due date와 혼동하지 않도록 명세서 마감일(closing date)로 표기
- 일반 캘린더의 월간 조회와 카드별 billing-cycle 조회는 서로 다른 기간이다. 카드별 범위는 이전 달과 다음 달에 걸칠 수 있으며, 거래일 `transacted_at`을 해당 범위에 한 번만 포함해 집계한다. 월말·윤년·연도 경계와 결제수단별 서로 다른 마감일은 구현 시 테스트한다.
- **UI 미정**: 카드 선택 시 사이클 시작일이 보이도록 달력 배치를 재구성하는 방향을 검토한다. 이전/다음 달 날짜를 월간 그리드에 함께 노출할지와 카드별 그리드의 최종 배치는 디자이너 비교 후 결정한다. 이 UI 논의만으로 DB 컬럼을 추가하지 않는다.

---

## 4.1 기본 카테고리 정의

가입 시 자동 생성되는 기본 카테고리 12개. 각 정의는 `categories.description`에 저장되며 LLM 파싱 프롬프트에 그대로 사용된다. 카테고리 목록은 운영팀이 관리하고 사용자는 지출 또는 영수증 품목에 적용할 카테고리만 선택한다.

| 카테고리 | 담당 범위 | 예시 | 아닌 것 (경계) |
|---|---|---|---|
| **Food** | 식료품 — 직접 조리/섭취할 먹거리 구매 | 마트 장보기(고기, 채소, 과일, 음료, 스낵) | 외식·배달은 Dining, 세제·휴지는 Living |
| **Living** | 생활용품·소모품 — 집에서 쓰는 물건 전반 | 세제, 휴지, 샴푸, 수건, 주방용품, 수납용품, 가구, 가전(냉장고·청소기) | 옷은 Fashion, 전자기기는 Electronics |
| **Electronics** | 전자기기·주변기기 하드웨어 | 폰, 노트북, 모니터, 이어폰, 충전기, 게임 콘솔 | 게임 소프트웨어·콘텐츠는 Entertainment, 디지털 구독은 Subscription, 가전은 Living |
| **Fashion** | 몸에 걸치는 것 | 옷, 신발, 가방, 액세서리, 화장품 | 세탁 서비스는 Etc |
| **Dining** | 조리된 음식·음료 구매 | 레스토랑, 카페, 배달(DoorDash 등), 술집 | 마트 식재료는 Food |
| **Transport** | 이동 비용 | 개스, 대중교통, Uber/Lyft, 주차, 차량 정비 | 여행지 항공·숙박은 Travel |
| **Subscription** | 반복 결제 디지털/멤버십 서비스 | Netflix, Spotify, iCloud, 짐 멤버십, Amazon Prime | 일회성 구매는 해당 카테고리로 |
| **Utilities·Bills** | 주거 관련 고정 요금 | 전기, 수도, 개스(주거), 인터넷, 휴대폰 요금 | 렌트는 MVP 범위 외 |
| **Health** | 건강·의료 | 병원, 약국, 보험 본인부담금, 영양제 | 짐 멤버십은 Subscription |
| **Entertainment** | 여가·취미 소비 | 영화, 공연, 게임, 책, 취미용품 | 반복 결제형(게임 구독 등)은 Subscription |
| **Travel** | 여행 관련 지출 일체 | 항공권, 호텔, 여행지 액티비티 | 일상 이동은 Transport |
| **Etc** | 위 어디에도 속하지 않는 것 | 선물, 기부, 수수료, 분류 애매한 지출 | — |

**분류 원칙**: 경계가 애매하면 "어디서 샀는가"가 아니라 "무엇을 샀는가" 기준. 같은 Target 영수증이라도 사과는 Food, 세제는 Living, 티셔츠는 Fashion으로 품목별 분류 (영수증 파싱의 존재 이유).

**향후 카테고리 검토 예시 — Pet**: 반려동물 지출을 Food·Fashion·Health에 흩어 놓으면 펫 지출 총액을 보기 어렵다. 다만 Pet은 모든 사용자에게 필요하지 않으므로 기본 세트에는 포함하지 않는다. 운영팀이 수요를 보고 Pet, Gift, Education, Kids 등의 추가 여부를 결정한다. 새 카테고리를 도입할 때는 신규 가계부의 기본 목록뿐 아니라 기존 가계부에도 반영해야 한다.

---

## 5. 핵심 화면 (와이어프레임 확정)

**네비게이션**: Bottom navigation bar (모바일 퍼스트 — 엄지 도달 범위, 한 손 조작)

`[ 홈(캘린더) ] [ 대시보드 ] [ ➕ 입력 ] [ 내 지갑 ] [ 설정 ]`

**네비게이션**: Bottom navigation bar (모바일 퍼스트 — 엄지 도달 범위, 한 손 조작)

`[ 홈(캘린더) ] [ 대시보드 ] [ ➕ 입력 ] [ 내 지갑 ] [ 설정 ]`

- 중앙 ➕ 버튼 강조 (최다 사용 액션) → 탭 시 "직접 입력 / 영수증 촬영" 선택 시트

- MVP는 iOS·Android 모바일 화면에 집중하며 웹·데스크톱 레이아웃은 범위에서 제외

**UI 용어 결정**: 화면 표기는 "결제수단" 대신 **"내 지갑"**, 등록 행위는 **"카드 추가"** — "결제수단 등록"은 실결제 연동(카드번호 입력)으로 오인되기 쉬움. "내 지갑"은 카드+현금을 포괄하는 은유이며, "지갑에 카드를 추가한다"는 문장이 연동 뉘앙스 없이 자연스러움. **DB/코드는 `payment_method` 유지** (UI 용어와 코드 용어 분리 — wallet은 개발 맥락에서 암호화폐 등 다른 의미가 강함). 이하 문서의 "결제수단"은 개념 지칭이며 화면 라벨은 "내 지갑/카드 추가"를 사용.

1. **홈 — 캘린더 뷰**: 월간 캘린더를 크게 표시 (통합 캘린더 — 모든 결제수단)

- Detail Mode를 기본 화면으로 하고, Simple Mode에서는 주요 closing date 중심으로 정보를 축약한다. 모드 전환 UX와 저장 위치는 TBD.
- 날짜별 메모 추가 방향을 반영한다. 메모 존재 여부는 아이콘 상태로 표시할 수 있으나 시각적 표현은 디자인 단계에서 확정한다. 날짜 메모는 거래별 `transactions.memo`와 별개다.
- 일반 월간 조회는 월 단위 탐색을 유지한다. 현재 월의 미래 날짜도 다른 날짜와 같은 기본 스타일로 표시한다. 카드 선택 시 사이클 범위를 반영하는 달력 배치는 아직 TBD.

- 날짜 셀에는 그날 사용된 **결제수단별 색 도트**만 표시 (금액 합계 없음 — 셀 단순화, cash-like도 색 보유)

- 카드별 closing date 셀은 해당 카드 색으로 하이라이트 + **현재 사이클 누적액만 표시** (예: 파란 배경에 "$1,240") — 카드명은 생략, 색이 카드를 식별. "이번 카드값 예상액"을 캘린더에서 바로 확인. 색-카드 매핑은 캘린더 하단 범례로 제공

- 오늘 날짜는 테두리 강조, 하단 패널에 오늘 거래 내역 기본 표시. 다른 날짜 탭 → 그날 거래로 전환 (카드별 구분 표시)

- 상단에 현재 보고 있는 달의 지출 합계 요약 한 줄

2. **대시보드 (메뉴 탭)** — 스크롤 순서: 사이클 카드 → 일별 바 차트 → 카테고리 도넛 → 현금성 박스

- 카드별 사이클 카드: 카드 색 점 + 이름 + 마감 D-day + 현재 사이클 지출액(큰 숫자) + 진행률 바 + 사이클 기간 표기

- **일별 지출 바 차트 (최근 30일)**: 날짜별 지출 합계 막대, 결제수단 색으로 스택 — 주간 패턴·과소비 구간 시각화. 막대 탭 시 해당 날짜 금액 툴팁

- 카테고리 도넛 차트 + 비율 리스트

- 현금성 지출은 사이클 없이 월 기준 별도 박스

- (Phase 2~3) 사이클 페이스 비교: 지난 사이클 같은 시점 누적액 vs 현재 — "이대로면 카드값이 지난달보다 많음"을 마감 전 예고. 한 사이클 이상 데이터 축적 후 활성화

- **후보·미확정**: 결제수단별 breakdown, 두 막대의 동일 경과 구간 사이클 비교, 선택형 위젯·순서 변경. 추세는 Daily/Monthly를 우선 검토하고 Weekly는 제외하는 방향이다. Monthly 범위(최근 12개월/해당 연도), 위젯 구성 저장 위치는 TBD이며 기본 대시보드 확정 항목으로 취급하지 않는다.

3. **지출 입력 (직접 입력)**: 금액 크게 → 결제수단 칩 → 카테고리 칩 → 날짜/메모 순. 3탭 이내 목표. 카드 칩 색상은 등록 시 지정한 색과 일치

- 저장된 거래의 수정·삭제 경로를 제공하는 방향이다. 금액·결제수단 변경과 영수증 파싱 후 편집 화면의 재사용을 검토하되, 최초 등록과 기존 거래 편집의 버튼·동작은 구분한다. 편집 진입 위치, 품목 수정 범위와 삭제 방식은 TBD이며 현재 거래 수정·삭제 API는 구현되지 않았다.

4. **입력 선택 시트**: ➕ 탭 시 "직접 입력 / 영수증 촬영" 2택. 영수증 옵션에 남은 무료 파싱 수 상시 노출 (예: "이번 달 7장 남음") — 한도를 미리 인지시켜 초과 시 반감 완화

5. **영수증 파싱 확인**: merchant/날짜/결제수단 헤더 + "AI 분류" 배지. 품목 리스트 각각 이름/가격/카테고리 칩(탭하여 변경). Tax·Tip은 회색 라인으로 구분. 하단에 합계 + 영수증 total 일치/불일치 검증 배지. "품목 추가" 보조 버튼 + "N건 모두 저장" 주 버튼. 원본 이미지 재열람 UI는 제공하지 않는다.

6. **내 지갑 — 카드 추가**: 타입(신용카드/현금성) 2택이 맨 위 — 현금성 선택 시 마감일 섹션 숨김(조건부 폼). 이름 입력 → 마감일 1~31 그리드 선택("결제일이 아닌 명세서 마감일" 경고 문구 포함) → 선택 즉시 "현재 사이클: 8/6 – 9/5" 실시간 미리보기 → 색상 6택 (캘린더 마커·대시보드와 연동)

7. **무료 한도 초과 팝업**: "이번 달 무료 파싱을 모두 사용했어요 (10/10) · 다음 달 초기화" 안내. **주 버튼 = "직접 입력하기"** (막힌 사용자 먼저 구제), 보조 버튼 = "Pro 플랜 보기 · 월 50장" (⚠️ 수치 미확정, 업셀은 2순위). 직접 입력 중 업로드한 이미지를 임시로 볼지와 종료 시 폐기 시점은 TBD이며 저장 후 원본 재열람은 제공하지 않는다.

7-1. **카드 개수 초과 게이트** (⚠️ 등급 구조 미확정): 무료 회원이 한도 초과 카드 추가 시도 시 모달 — "무료 플랜은 카드 2개까지예요. Pro에서 무제한으로 추가하세요" + [Pro 보기] / [닫기]. 파싱 한도 팝업과 동일 모달 패턴 재사용

8. **온보딩 (2단계)**:

- 시작: 가치 제안 한 줄("카드 마감일 기준으로 지출 추적") + "계속하기"(현행 Email/Password·이메일 인증) / "가입 없이 둘러보기"(체험 모드 — 기기 저장·앱 삭제·기기 변경 시 소실 가능 문구 명시). Google/Apple 등 다른 인증 방식은 별도 검토 대상

- 첫 카드 등록: "카드번호는 필요 없어요 — 이름과 마감일만" 문구로 연동 앱 대비 경계심 해소. 마감일 빠른 선택(1일/5일/15일/직접). 건너뛰기 허용. 등록 즉시 홈 진입

---

## 6. 영수증 파싱 플로우 (Phase 2)

```

이미지 업로드

→ 백엔드에서 Vision LLM API 호출

프롬프트: "영수증에서 merchant, 날짜, 품목별 {name, price, 추정 category}를

아래 JSON 스키마로 추출" (structured output)

+ tax/tip 분리 + 할인/쿠폰 라인(음수 금액) 처리 명시

+ 품목명 정규화("WHL MLK 2%" → "Whole Milk 2%")

+ PII(이름·카드번호·멤버십 번호) 추출 금지

→ categorization_rule 매칭으로 카테고리 덮어쓰기 (개인화)

→ 프론트에 draft 반환 → 사용자 확인/수정 → transaction 일괄 생성

```

**원본 이미지 비보관 방향 (2026-10-17 미팅)**: 파싱에 사용한 영수증 원본은 영구 저장하지 않고, 저장된 거래·확인 화면에서 원본 이미지를 다시 여는 기능도 제거한다. 임시 파일·Storage 사용 여부, 실패/중단 시 삭제 시점과 사용자 고지는 구현 전 TBD다. 이미지가 Gemini 등 외부 API로 전송되는 개인정보 문제는 비보관 결정만으로 해결되지 않는다.

**비용/과금 모델**: freemium 3단 구조 (비회원 체험 총 3장 / 무료 회원 월 10장 / Pro 월 50장 ⚠️ 미확정 — 상세는 "회원 등급 구조" 참조).

- MVP 기간에는 무료 카운팅 로직만 구현 (유료화 시 그대로 재사용)

- 무료 회원 파싱 한도는 **Supabase `user_id` 기준**으로 계산. 현행 Email/Password·이메일 인증 외에 다른 인증 수단을 도입하더라도 내부 소유권 키는 `user_id`로 유지

- 이미지 리사이즈 후 전송으로 장당 원가 절감

**Tax/Tip 처리**: 특정 품목에 속하지 않는 금액은 별도 품목 transaction으로 생성.

- LLM 파싱 시 tax, tip을 품목과 분리 추출 → 확인 화면에 별도 라인으로 표시 (수정 가능)

- 저장 시 각각 transaction row → `SUM(품목) + tax + tip = 영수증 총액` 항상 성립

- 파싱 합계 ≠ 영수증 total이면 확인 화면에서 차액 경고 (파싱 오류 검증 장치)

**카테고리 운영 원칙**:

1. 기본 카테고리: 가입 시 자동 생성 (`is_default = true`) — 확정 세트 (12개):

Food (식료품) / Living (생활용품·소모품·가전: detergent, 휴지, 수건, 주방용품 등) / Electronics (전자기기·주변기기 하드웨어) / Fashion (옷·신발·액세서리) / Dining (외식·카페·배달) / Transport / Subscription / Utilities·Bills / Health / Entertainment / Travel / Etc

- `categories.description` 컬럼 추가: 각 카테고리의 한 줄 정의. LLM 파싱 프롬프트에 이름+설명을 함께 제공해 분류 정확도 확보 (예: Target 영수증에서 detergent → Living, 사과 → Food)

2. 운영팀 관리: 사용자는 카테고리 목록을 조회하고 지출에 적용할 항목을 선택하지만, 카테고리 자체를 추가·변경·삭제하지 않는다. 운영팀이 새 카테고리를 도입하면 기존 가계부에도 반영한다.

3. AI는 추천만: 파싱 시 해당 가계부의 카테고리 목록(이름+설명)을 프롬프트에 제공하고 그 안에서만 선택한다. AI가 새 카테고리를 만들 수는 없다. 사용자의 품목별 분류 수정은 `categorization_rules`에 축적해 개인화한다.

**실패 처리**: 파싱 실패/저신뢰 시 "수동 입력으로 전환" fallback 제공.

**무료 한도 초과 시 동작**: 영수증 업로드 자체는 항상 가능 — 차단되는 건 AI 파싱뿐.

- 한도 초과 상태에서 업로드 시 팝업: "이번 달 무료 파싱을 모두 사용했어요" + 유료 플랜 안내

- 팝업에서 바로 **수동 입력 모드로 전환**: 이미지가 현재 입력 세션에 남아 있다면 임시 참고용으로 보여줄 수 있으나, 저장 후 재열람이나 영구 보관은 하지 않는다. 임시 표시·폐기 시점은 TBD다.

- 과거 영수증 원본을 재파싱하는 업셀은 제공하지 않는다.

---

## 6.1 프라이버시 (영수증 = 개인정보 취급)

영수증에는 이름, 카드번호 뒷자리, 멤버십 번호, 배달 주소, 약국 영수증의 경우 의료 정보까지 포함될 수 있음. 특히 이미지가 **제3자(LLM API 제공사)로 전송**된다는 점은 명시적 고지 대상.

1. **첫 업로드 시 1회 안내** (필수): "영수증 이미지는 품목 분류를 위해 AI 서비스로 전송돼요. 카드번호 등 민감 정보가 보이지 않게 찍는 걸 권장해요." — 매번 묻지 않고 1회 + 설정에서 재확인 가능

2. **약관·개인정보처리방침 동의**: 온보딩 "이메일로 시작하기" 하단에 동의 문구 한 줄. 방침에는 확인된 수집 항목(영수증 이미지, 지출 기록), 제3자 전송, 실제 임시 보관·삭제 시점, 삭제 요청 방법을 반영한다. **일반 공개·유료화 전 방침 문구는 템플릿/전문가 검토 필수** (CCPA 및 App Store·Google Play 심사 요건)

3. **설계로 리스크 축소** (문서보다 강력한 방어):

- 파싱 프롬프트에서 품목/가격/상호/날짜만 추출하도록 요청하고 **이름·카드번호·멤버십 번호는 추출 금지**를 명시한다. 다만 프롬프트만으로 추출 결과·로그의 PII 유입을 막는다고 보장할 수 없어 검증이 필요하다.

- Gemini 등 외부 API의 실제 전송·보존·학습 정책을 출시 전에 확인하고, 고지 문구를 그 결과에 맞춘다. 원본 비보관만으로 제3자 전송 위험이 사라지는 것은 아니다.

- 임시 Storage가 필요하다면 private bucket과 짧은 접근 기한을 적용한다. 비회원 이미지를 포함해 성공·실패·중단 시 임시 파일 폐기 시점은 구현 전 확정한다.

4. **계정 삭제 = 데이터 전체 삭제** 버튼: 설정 화면에 필요, 방침의 약속을 지키는 실제 기능

---

## 6.2 운영·시스템 원칙

**삭제 정책 (거래 개별 삭제 방식은 TBD)**:

- 저장된 거래의 삭제 경로는 필요하다. 현행 `transactions.deleted_at` 컬럼은 있으나 soft delete와 hard delete 중 실제 정책, 영수증 품목·quota와의 관계는 확정되지 않았고 삭제 API도 없다.

- 계정 삭제 시 데이터 전체 삭제 방향은 유지한다. 원본 이미지는 영구 보관하지 않으므로, 임시 이미지가 남아 있다면 함께 폐기해야 한다.

**파싱 상태 머신 & quota 차감**:

```

pending → (LLM 호출 성공: 이 순간 quota 차감) → draft → (유저 저장) → parsed

└→ (LLM 에러 / 품목 0개) → failed : 차감 없음, 재시도 유도

```

draft·failed 이미지의 7일 보관은 이번 원본 비보관 방향과 충돌하므로 폐기한다. draft 재방문과 failed 디버깅을 이미지 없이 지원할지, 임시 이미지의 실패·중단 시 삭제 시점을 어떻게 보장할지는 TBD다.

- 차감 기준 = "유저가 파싱의 가치를 받았는가" — 결과가 나오면(draft) 차감, 시스템이 실패하면(failed) 무차감. "저장 시 차감"은 결과만 보고 이탈하는 우회를 허용하므로 채택하지 않음

- **실패 로그 후보**: 원본 이미지 대신 오류 유형·품목 수·이미지 크기·모델명 등 최소한의 메타데이터를 검토한다. 개인정보 포함 여부와 보존 기간은 TBD이며, 이미지 보관을 전제로 한 디버깅 창은 두지 않는다.

- quota 정의 갱신: `receipts WHERE status IN ('draft','parsed') AND 이번 달` COUNT (deleted 무관)

- 고지: 첫 파싱 시 프라이버시 안내와 통합 1회 팝업("AI 전송 + 차감 + 결과는 저장됨"), 이후엔 실행 버튼에 잔여 수 상시 표시("파싱하기 · 9장 남음")

**어뷰징 방어 (층 구조 — 원칙: 완벽 차단이 아니라 "뚫려도 손해 유한")**:

1. Rate limiting: `/parse-trial`(비인증)은 IP당 시간 3회·일 5회, 가입 엔드포인트도 IP 제한 (FastAPI slowapi)

2. 보이지 않는 봇 체크 (Cloudflare Turnstile 등) — 파싱 요청에만, 유저 마찰 0 *(실제 어뷰징 관측 후 도입)*

3. 이미지 사전 검증 — LLM 호출 전 크기·포맷 체크와 재인코딩·EXIF 제거를 수행한다.

4. **전역 서킷브레이커: 일일 LLM 지출 상한 (예: $5) 도달 시 체험 파싱 자동 중단 + 알림** — 모든 층이 뚫려도 최대 손해를 캡. 구현 최소(일일 카운터 + if문), 1주차 필수

- SMS 인증은 기각 — 발송 비용이 역으로 공격면이 되고, "카드번호도 안 받는 앱" 포지셔닝과 충돌

**모니터링 3종 (전부 무료 티어, 1주차 셋업)**:

1. Uptime: UptimeRobot이 5분마다 `/health` 확인 → 다운 시 이메일. `/health`는 단순 200이 아니라 **DB SELECT 1 성공 시 200** — 서버 생존 + DB 연결을 한 번에 감지

2. 에러 트래킹: Sentry (FastAPI + Flutter SDK) — "살아있는데 특정 API만 실패"하는 부분 장애 감지

3. 비용 알림: 서킷브레이커 발동 시 이메일 (어뷰징 방어 4번과 동일 장치)

**스키마 마이그레이션 규칙**:

- 마이그레이션 = 코드: 모든 스키마 변경은 Alembic revision 파일로 (upgrade + downgrade 정의), git PR 리뷰 필수 (스키마 최종 승인 = 리드)

- 팀원 동기화: `git pull` 후 `alembic upgrade head` 한 줄

- 프로덕션 실행 전 Supabase 스냅샷 백업. Postgres DDL은 트랜잭션이라 마이그레이션은 all-or-nothing (반쯤 실패 상태 없음)

- 파괴적 변경(컬럼 삭제·개명)은 2단계: 새 컬럼 추가 + 양쪽 쓰기 → 안정 확인 후 별도 마이그레이션에서 제거 — "추가는 즉시, 삭제는 한 박자 뒤"

**보안 체크리스트**:

- **인가(Authorization)**: JWT 검증(인증)과 별개로, 모든 엔드포인트에서 "이 유저가 이 ledger의 멤버인가" 검사 — FastAPI 공용 의존성(`get_user_ledger`: 토큰 user → 멤버십 확인 → 실패 시 404) 하나를 모든 라우터가 통과. ID는 순번이 아닌 UUID(추측 차단, 기결정). URL의 ledger_id만 바꿔 남의 데이터를 읽는 IDOR가 이 유형 앱의 취약점 1위

- **Supabase RLS (1주차 필수)**: 모든 테이블에 RLS 활성화 + 기본 정책 전부 거부. anon key는 공개 키라서 RLS 없이는 FastAPI를 우회해 Supabase REST로 테이블 직접 조회 가능 — 스택 특유의 뒷문. FastAPI는 service role 키 사용이므로 영향 없음

- **업로드 파일 검증 + 재인코딩**: 확장자가 아닌 실제 바이트(magic bytes) 확인 + 크기 상한(예: 10MB) + 서버 재인코딩 — 악성 페이로드 무력화 + 리사이즈(기결정) + **EXIF 제거(GPS 좌표 = 위치 이력, 프라이버시 원칙 직결)** 를 한 파이프라인에서

- **임시 Storage 접근 규율**: 임시 저장이 필요해 짧은 접근 URL을 쓴다면 수 분 내 만료시키고 ledger 멤버십을 확인한다. 저장 후 원본 조회 URL은 제공하지 않는다.

- **프롬프트 인젝션 (LLM 앱 고유)**: 영수증에 인쇄된 악성 지시문 대비 — structured output 강제 + 파싱 결과는 항상 데이터로 취급(실행 경로 없음) + 확인 화면의 사람 검토로 현재 커버. Phase 3 챗봇의 tool calling 원칙("LLM은 정의된 함수만 선택")이 같은 방어의 연장

- **기타 스위치**: CORS는 프론트 도메인만 허용(와일드카드 금지) · JWT는 서명+만료+audience 검증(Supabase JWKS) · 로그·Sentry에 PII scrub(이미지·금액·이메일 제외) · GitHub Dependabot 활성화

- 우선순위: 1주차 = RLS + 멤버십 의존성 + CORS 잠금 / 파싱 구현 시 = 파일 검증·재인코딩·presigned 규율 / 상시 = 로그 위생·Dependabot

---

## 6.3 검색 범위 (후보·미확정)

- 우선 검토 대상은 정확한 품목명 검색과 카테고리·상점 필터다. 부분 일치의 범위와 검색 대상 데이터 구조는 TBD다.
- `coffee` 검색이 `latte`를 자동으로 찾는 의미 검색은 기본 제공으로 가정하지 않는다. 필요성이 확인되면 별도 기능으로 설계한다.

---

## 7. 마일스톤 (제안)

| 주차 | 목표 |
|---|---|
| 1주 | 프로젝트 셋업 (FastAPI + Flutter), Supabase/Auth 기본 설정, DB 스키마, 결제수단 생성·조회와 카테고리 목록 조회, 모니터링 3종 + rate limit + 지출 캡 + RLS·멤버십 의존성 |
| 2주 | 지출 입력 + 거래 내역 + 사이클 계산 로직 (테스트 포함) |
| 3주 | 대시보드 (사이클 카드, 차트) — 여기까지가 Phase 1 완성 |
| 4주 | 영수증 파싱 파이프라인 + 확인 UI |
| 5주 | 개인화 규칙, 폴리싱, 배포 |
| 6주~ | 실사용 피드백 → 공유 기능 여부 결정 |

---

## 8. 리스크 & 열린 질문

- **통합 뷰 UX**: ✅ 결정 — 카드별 사이클이 제각각이므로 "이번 달 총 지출"은 "최근 30일 rolling"으로 통일, 사이클 집계는 카드별 뷰에서만 표시

- **파싱 정확도**: 구겨진 영수증, 손글씨, 비영어 영수증 → 확인 화면이 필수 안전망

- **LLM API 비용**: freemium으로 커버 (Phase 2에서 카운팅, Phase 3에서 과금). 유료 유저 원가 대비 가격 마진 검증 필요

- **currency**: ✅ 결정 — USD 단일. 본인 + 초기 테스터 모두 미국 거주. `transaction.currency` 컬럼은 'USD' 기본값으로 유지해 향후 다중 통화 확장 여지만 남김 (지금 복잡도 0)

- **인증 범위**: ✅ 방향 결정 — Guest 사용 허용 + 회원은 Email/Password + Email Verification을 기본으로 사용. credential은 Supabase Auth가 관리하고 앱 데이터는 Supabase `user_id` 기준으로 연결. Google/Apple 로그인과 Account Linking은 일정에 따라 확장
