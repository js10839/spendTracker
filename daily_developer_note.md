Today, I set up the project with fastAPI for backend and react for frontend.
Here are what I did:

1. seperate folders in to two parts: frontend / backend
    * For frontend, set up very first react stuff that's necessary to setup
    * Choose typescript over javascript since typescript is preferable on the project where types are important. Since this project is closely focused on categorizing the products, typescript works well on finding the errors on schema and values
    * For backend, set up fastAPI and uv.
    * Choose fastAPI for fast mvp build up and free in constructing the folders and files
    * Also choose uv instead of all the other python related tools like pip, pytest, etc for speed. Since uv is built on Rust, much faster and safer than other python tools as far as I remember
2. set up basic CI on github action for the future project members
    * This setup was copied from uv and react ci website, modified by GPT. I used CI from my last internship and good to have to check all environment checks(lint/builds & lint/test) that human might miss
3. Create readme.md and agents.md file for the future project members.
4. CORS
5. Health test
6. Supabase DB setup

---

## 2026-10-14 — 공통 인증·ledger 접근 의존성

### 오늘 한 일

- 팀원이 `receipts`, `cycles`, `dashboard` API를 같은 방식으로 개발할 수 있도록 백엔드 공통 인증·인가 의존성을 만들었다. 로그인·회원가입 API는 아직 만들지 않았다.
- `get_current_user_id`가 Bearer 토큰을 읽고, Supabase JWKS 공개키로 JWT의 서명·만료 시간(`exp`)·발급자(`iss`)·대상(`aud`)·역할(`role`)을 검증한 뒤 `sub`를 사용자 UUID로 반환하게 했다.
- `get_user_ledger`가 URL의 `ledger_id`와 인증된 `user_id`로 `ledger_members`를 조회해 접근 가능한 ledger만 반환하게 했다. 멤버가 아니거나 ledger가 없으면 동일하게 404를 반환한다.
- DB 조회는 `ledgers/repository.py`, 접근 판단은 `ledgers/service.py`, FastAPI 의존성 연결은 `ledgers/dependencies.py`에 두었다.
- `SUPABASE_URL` 설정과 선택적 `SUPABASE_JWKS_URL`을 추가하고, 팀원이 사용할 방법을 README에 기록했다. JWT 검증을 위해 PyJWT 의존성을 추가했다.

### 왜 이렇게 했나

- 로그인 기능 구현과 별개로, 각 기능 API가 공통으로 재사용할 사용자 식별·ledger 접근 검사가 필요했다.
- 토큰의 `sub`를 읽기만 해서는 사용자를 신뢰할 수 없으므로 서명과 주요 claim을 검증한다.
- 모든 ledger 소유 데이터 접근에서 멤버십 검사를 거쳐 다른 사용자의 `ledger_id`로 조회하는 일을 막는다. 각 기능의 repository도 데이터 조회 시 `ledger_id` 조건을 유지해야 한다.
- Supabase 설정이 없는 CI에서도 기존 health 테스트가 돌아가도록, 인증이 필요한 요청에서만 설정 누락을 503으로 알린다.

### 확인한 결과

- Ruff 검사와 포맷 검사 통과, 백엔드 테스트 14개 통과, `uv.lock` 확인 완료.
- 테스트에서는 JWKS와 DB를 대체했다. 실제 Supabase 토큰과 DB를 이용한 연결 테스트는 아직 하지 않았다.

### 다음 할 일

- 로컬 `backend/.env`에 실제 `SUPABASE_URL`을 설정하고, 프로젝트가 비대칭 JWT 서명 키를 사용하는지 확인한다. 현재 JWKS 방식은 비대칭 서명 토큰을 대상으로 한다.
- 실제 사용자 토큰으로 보호된 테스트 경로를 호출해 검증한다. 아직 실제 기능 라우터에는 공통 의존성이 연결되지 않았다.
- ledger 생성 기능을 만들 때 소유자를 `ledger_members`에도 추가한다. 그래야 소유자도 `get_user_ledger` 검사를 통과한다.

---

## 2026-10-16 — SQLAlchemy와 직접 SQL 사용 기준

### 오늘 정리한 질문

- PostgreSQL을 쓰기 때문에 SQLAlchemy가 필요한가? **아니다.** PostgreSQL에도 `psycopg`로 직접 SQL을 실행할 수 있다. SQLAlchemy는 DB 종류가 아니라 백엔드 코드 관리 방식에 대한 선택이다.
- SQLAlchemy가 더 빠르거나 직접 SQL보다 항상 좋은가? **아니다.** 직접 SQL도 실무적인 선택이며, 쿼리의 명확성과 실제 성능은 용도에 따라 판단해야 한다.
- SQLAlchemy를 쓰면 나중에 직접 SQL을 못 쓰거나 구조를 바꾸기 어려운가? **아니다.** 같은 SQLAlchemy `Session`에서 직접 SQL을 실행할 수 있고, 모델과 구조도 필요에 따라 변경할 수 있다.

### 이 프로젝트의 결론

- MVP에서는 **Sync SQLAlchemy를 기본 DB 접근 방식으로 유지**한다. `User`, `Ledger`, `Transaction` 같은 공통 모델과 `Session`을 사용하면 여러 개발자가 테이블과 트랜잭션을 같은 방식으로 다룰 수 있다. 반복적인 CRUD에서 연결·결과 매핑 코드를 매번 직접 작성할 필요도 줄어든다. 이것이 선택 이유이지, PostgreSQL의 필수 조건이나 성능상의 우월성 때문은 아니다.
- **복잡한 집계는 필요할 때 직접 SQL을 사용**한다. 특히 대시보드의 합계·그룹별 집계처럼 SQL로 표현하는 편이 명확한 쿼리가 대상이다. 직접 SQL도 `Repository` 안에서 실행하고, 값은 문자열에 끼워 넣지 않고 바인딩한다. `Service`는 비즈니스 규칙과 commit/rollback을 담당한다.
- **사이클 계산은 SQL로 전부 옮기지 않는다.** Repository가 필요한 거래를 조회하고, 마감일에 따른 기간 계산 같은 핵심 규칙은 테스트 가능한 도메인 코드에 둔다.
- `SQL injection`은 “SQL을 직접 작성한다”는 뜻이 아니라, 입력값을 SQL 문자열에 안전하지 않게 삽입할 때 생길 수 있는 보안 취약점이다. 직접 SQL을 쓸 때는 `text("... WHERE ledger_id = :ledger_id")`와 매개변수 전달처럼 안전한 바인딩을 사용한다.

### Alembic은 왜 유지하나

- SQLAlchemy 모델을 수정해도 실제 DB의 기존 테이블 구조가 자동으로 바뀌지는 않는다. Alembic은 컬럼·테이블 등 **스키마 변경 파일의 순서와 적용 버전**을 관리한다. 자동 생성한 마이그레이션도 적용 전에 검토해야 한다.
- SQLAlchemy를 쓴다고 Alembic이 필수는 아니다. `onetouch_copy`는 직접 SQL 변경 파일과 별도 실행·검증 스크립트를 사용하고, `juliatalk`은 서버 시작 시 새 테이블 생성과 별도 `ALTER TABLE`을 수행한다. 우리 팀은 이미 SQLAlchemy 모델과 첫 Alembic 마이그레이션이 있으므로, 자체 변경 관리 체계를 새로 만들기보다 Alembic을 유지한다.
- 기본 카테고리처럼 **새 사용자·가계부마다 생성하는 데이터**는 스키마 마이그레이션 대상이 아니다. 계정 초기화 Service가 Repository를 통해 생성한다.

### 앞으로의 판단 기준

- 기본 CRUD는 SQLAlchemy 모델로 시작하고, 직접 SQL이 더 읽기 쉽거나 실제 쿼리 문제가 확인된 부분만 직접 SQL로 작성한다.
- ORM 사용 자체를 목표로 삼지 않는다. 직접 SQL이 대부분이 되는 상황이라면 SQLAlchemy를 유지할 이점도 다시 평가한다.

### 사용자와 가계부 UUID는 어디서 오나

- **사용자 UUID는 Supabase Auth가 회원가입 시 발급**한다. 이후 로그인 토큰의 `sub`에 담긴 값을 백엔드가 검증해서 사용하며, 로그인이나 `bootstrap` 호출마다 새로 만들지 않는다.
- `bootstrap_user()`는 이 UUID를 그대로 `public.users.id`에 사용한다. 따라서 `public.users.id`와 `auth.users.id`는 같은 사용자를 가리키는 동일한 값이다. 이미 프로필이 있으면 다시 생성하지 않는다.
- **가계부 UUID는 우리 앱이 새 가계부를 저장할 때 생성**한다. `Ledger.id`의 SQLAlchemy `uuid4` 기본값을 사용하며, `flush()` 후 그 ID로 소유자 멤버십과 기본 카테고리를 연결한다. 사용자 UUID와 가계부 UUID는 서로 다른 값이다.
- `bootstrap`은 Supabase 회원가입·로그인 자체가 아니라, 인증된 사용자를 위해 앱 프로필·개인 가계부·소유자 멤버십·기본 카테고리를 처음 준비하는 과정이다. 네 작업을 하나의 트랜잭션으로 묶어 모두 성공할 때만 commit한다.
