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
