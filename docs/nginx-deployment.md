# Nginx Deployment

[`deploy/nginx/spendtracker.conf`](../deploy/nginx/spendtracker.conf)를 사용해 프록시를 배포하고 요청 제한을 확인하는 방법을 설명합니다.
별도 안내가 없으면 명령어는 저장소 루트에서 실행합니다.

아래 명령들은 systemd를 사용하는 ***Linux 배포 서버*** 기준입니다. 


아래 명령어로르 통해 배포 서버에 Nginx를 설치합니다. 

```bash
sudo apt update
sudo apt install nginx
nginx -v
```

### 주요기능 
0. Config 적용
1. 요청 본문 크기 제한
2. IP별 영수증 파싱 요청 횟수 제한 


## 0. Config 적용

`proxy_request_buffering`설정을 통해, 요청 본문을 모두 받은 뒤 백엔드에 전달하도록 버퍼링을 활성화했습니다. `Content-Length`가 없는 청크 전송에도 적용됩니다. 

Nginx가 설치된 호스트에서 FastAPI를 루프백 주소에 바인딩해 실행합니다.

```bash
cd backend
uv run fastapi run app/main.py --host 127.0.0.1 --port 8000
```

저장소 루트에서 별도 터미널을 통해 프록시 설정을 설치하고, 문법 검사 후 다시 불러옵니다.
아래 명령은 `/etc/nginx/conf.d/`가 기존 Nginx의 `http` 블록에서 포함되고,
systemd로 Nginx를 관리하는 환경을 기준으로 합니다.

1. 프로젝트 설정 파일을 Nginx가 읽는 설정 폴더로 복사합니다. 
2. Nginx 설정에 문법 오류가 없는지 검사합니다. 
3. 실행 중인 Nginx가 수정된 설정을 다시 읽도록 합니다. 

```bash
sudo install -m 644 deploy/nginx/spendtracker.conf /etc/nginx/conf.d/spendtracker.conf
sudo nginx -t
sudo systemctl reload nginx
```

8080 포트에서 Nginx 요청을 받습니다. 운영 환경에서는 HTTPS 진입점의 요청을
8080 포트로 전달하거나, `server` 블록에 환경에 맞는 TLS 리스너와 인증서를 추가합니다.
크기·횟수 제한을 우회할 수 없도록, 실제 배포 시 **8000 포트는 외부에 공개하지 마세요.**
기존 게이트웨이로 Nginx를 대체한다면 같은 제한과 요청 본문 전체 버퍼링을 적용해야 합니다.
개발 중 8000 포트로 직접 보내는 요청에는 Nginx의 제한이 적용되지 않습니다.

정상 연결 여부는 서버에서 확인할 수 있습니다.
```bash
curl http://127.0.0.1:8080/health/live
```


## 1. 요청 본문 크기 제한

[Nginx 설정](../deploy/nginx/spendtracker.conf)을 적용하여 큰 요청이 FastAPI에 도달하기 전에 차단합니다. 모든 경로에서 **요청 본문 전체**를 11 MiB로 제한합니다. 이미지 10 MiB와 multipart 부가 데이터 최대 1 MiB를 고려한 값이며,
초과하면 JSON `detail`과 함께 HTTP 413을 반환합니다.
API에서도 이미지 파일에 대한 10 MiB 제한을 별도로 적용합니다.


### (테스트) 크기 제한 검증

11 MiB보다 큰 요청 본문을 프록시로 전송합니다. HTTP 413이 반환되고,
FastAPI 접근 로그에는 해당 요청이 남지 않아야 합니다. 

1. 테스트용 12MiB 임시 파일 생성
2. Nginx의 8080포트로 일반 파일 업로드
3. 전체 크기를 미리 알리지 않는 청크 업로드 

```bash
python3 -c 'from pathlib import Path; Path("/tmp/spendtracker-oversized.bin").write_bytes(b"x" * (12 * 1024 * 1024))'

curl -i http://127.0.0.1:8080/receipts/parse \
  -F 'file=@/tmp/spendtracker-oversized.bin'

curl -i --http1.1 http://127.0.0.1:8080/receipts/parse \
  -H 'Transfer-Encoding: chunked' -H 'Expect:' \
  -F 'file=@/tmp/spendtracker-oversized.bin'
```

10 MiB 이하의 정상 이미지도 8080 포트로 업로드해
일반 multipart 요청이 API까지 전달되는지 확인합니다.

## 2. 영수증 파싱 IP별 요청 횟수 제한

같은 Nginx 설정에서 `POST /receipts/parse`와 `POST /receipts/parse/`를
**IP당 평균 분당 5회**로 제한합니다. Guest와 로그인 사용자 모두 적용됩니다.
두 경로는 쿼리 파라미터와 관계없이 같은 한도를 공유합니다.
최대 5회의 연속 요청을 즉시 허용하며, 이후 12초마다 1회씩 요청 가능 횟수가 회복됩니다.


추후 다른 경로와 CORS `OPTIONS`를 포함한 다른 HTTP 메서드에도 한도를 추가할 수 있습니다. 
제한 검사를 통과한 요청은 이후 백엔드가 거부하거나 파싱에 실패하더라도 횟수에 포함됩니다.

한도를 초과한 요청은 FastAPI나 OpenAI에 전달하지 않고,
HTTP **429**, JSON `detail`, `Retry-After: 12` 헤더를 반환합니다.
정책을 조정할 때는 `rate=5r/m`, `burst=4`, 재시도 헤더와 안내 문구를 함께 검토하세요.
이 설정은 **요청 빈도를 제한**하며, 전체 일일 사용량이나 비용 상한을 보장하지는 않습니다.

### 프록시 뒤에서 클라이언트 IP 식별

제한 기준은 연결한 클라이언트의 IP입니다. 클라이언트가 임의로 보낸
`X-Forwarded-For` 헤더를 그대로 신뢰하지 않습니다.
Nginx 앞에 로드 밸런서나 CDN이 있다면, Nginx에는 사용자가 아니라 중간 서버의 IP가 보입니다. 
신뢰하는 프록시 주소만 `set_real_ip_from`으로 지정하고 해당 서비스가 안내하는 클라이언트 IP 헤더를 `real_ip_header`로 설정해야 합니다.
그렇지 않으면 프록시 뒤의 모든 사용자가 하나의 한도를 공유하게 됩니다.
임의의 클라이언트가 보낸 IP 헤더를 신뢰하도록 설정하지 마세요.
같은 공인 IP를 사용하는 사용자도 한도를 공유합니다.

``` bash
사용자 → 로드 밸런서 → Nginx → FastAPI
```


### (테스트) 횟수 제한 검증

위 절차에 따라 설정을 설치하고 다시 불러온 뒤, 이미지를 생략한 요청으로 확인합니다.
해당 검증은 OpenAI를 직접적으로 호출하지 않습니다.
아직 사용하지 않은 IP별 한도에서 시작하거나, 60초 동안 요청을 보내지 않은 뒤 실행합니다.

```bash
for attempt in 1 2 3 4 5 6; do
  curl -sS -o /dev/null -w '%{http_code}\n' -X POST \
    http://127.0.0.1:8080/receipts/parse
done
```

FastAPI가 실행 중이고 모든 요청이 12초 이내에 완료되면,
처음 5회는 `422`, 다음 요청은 `429`가 반환되어야 합니다.
제한된 상태에서 `/receipts/parse?probe=1`과 `/receipts/parse/`로도 요청해
모두 `429`가 반환되는지 확인합니다.
`curl -i -X POST`로 JSON 응답과 `Retry-After` 헤더를 확인할 수 있습니다.
12초 후 다시 요청하면 FastAPI까지 전달되어 `422`가 반환되어야 합니다.
파싱이 제한된 동안에도 `GET /docs`에 접근할 수 있는지 확인합니다.

## References

공유 메모리 영역과 순간 연속 요청 허용량(`burst`)의 동작은
[Nginx 요청 제한 공식 문서](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)를 참고하세요.
