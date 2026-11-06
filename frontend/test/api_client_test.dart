import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/api/api_client.dart';

void main() {
  ApiClient api(
    http.Client client, {
    AccessTokenProvider? token,
    String baseUrl = 'http://localhost:8000',
    Duration timeout = const Duration(seconds: 30),
  }) {
    final value = ApiClient(
      baseUrl: Uri.parse(baseUrl),
      accessToken: token ?? () => 'test-token',
      client: client,
      timeout: timeout,
    );
    addTearDown(value.close);
    addTearDown(client.close);
    return value;
  }

  test(
    'sends JSON headers and reads the supplied token for every request',
    () async {
      var token = 'first-token';
      final received = <http.Request>[];
      final client = api(
        MockClient((request) async {
          received.add(request);
          return http.Response(
            '{"value":"caf\u00e9"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        token: () async => token,
      );
      expect(await client.getJson(['users', 'me']), {'value': 'caf\u00e9'});
      token = 'second-token';
      await client.getJson(['users', 'me']);
      expect(received.first.headers['Authorization'], 'Bearer first-token');
      expect(received.last.headers['Authorization'], 'Bearer second-token');
      expect(received.first.headers['Accept'], 'application/json');
      expect(received.first.body, isEmpty);
      expect(received.first.followRedirects, isFalse);
    },
  );

  test(
    'preserves base path and encodes path segments and query values',
    () async {
      final client = api(
        MockClient((request) async {
          expect(request.url.pathSegments, [
            'api',
            'v1',
            'ledgers',
            'id/with space',
            'transactions',
          ]);
          expect(request.url.queryParameters, {'payment_method_id': 'a&b'});
          expect(request.url.host, 'example.com');
          return http.Response('[]', 200);
        }),
        baseUrl: 'https://example.com/api/v1/',
      );
      await client.getJson(
        ['ledgers', 'id/with space', 'transactions'],
        queryParameters: {'payment_method_id': 'a&b'},
      );
    },
  );

  test(
    'PUT sends an actual JSON body and accepts null or empty responses',
    () async {
      var requests = 0;
      final client = api(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {'content': 'Note\nwith "quotes"'});
          return ++requests == 1
              ? http.Response('null', 200)
              : http.Response('', 204);
        }),
      );
      for (var i = 0; i < 2; i++) {
        expect(
          await client.putJson(
            ['notes'],
            body: {'content': 'Note\nwith "quotes"'},
          ),
          isNull,
        );
      }
    },
  );

  test('missing/blank tokens fail locally without sending requests', () async {
    var requests = 0;
    for (final token in <String?>[null, '', '  ']) {
      final client = api(
        MockClient((_) async {
          requests++;
          return http.Response('[]', 200);
        }),
        token: () => token,
      );
      await expectLater(
        client.getJson(['users', 'me']),
        throwsA(isA<MissingAccessTokenException>()),
      );
    }
    expect(requests, 0);
  });

  test(
    '401 is exposed without refreshing tokens or retrying the request',
    () async {
      var requests = 0;
      final client = api(
        MockClient((_) async {
          requests++;
          return http.Response('{"detail":"Invalid access token"}', 401);
        }),
      );
      await expectLater(
        client.getJson(['users', 'me']),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.detail, 'detail', 'Invalid access token'),
        ),
      );
      expect(requests, 1);
    },
  );

  test(
    'keeps FastAPI validation details and handles plain-text server failures',
    () async {
      final details = [
        {
          'loc': ['query', 'start_date'],
          'msg': 'Invalid date',
        },
      ];
      final validation = api(
        MockClient(
          (_) async => http.Response(jsonEncode({'detail': details}), 422),
        ),
      );
      await expectLater(
        validation.getJson(['transactions']),
        throwsA(isA<ApiException>().having((e) => e.detail, 'detail', details)),
      );
      final server = api(
        MockClient((_) async => http.Response('Internal Server Error', 500)),
      );
      await expectLater(
        server.getJson(['transactions']),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 500)
              .having((e) => e.detail, 'detail', isNull),
        ),
      );
    },
  );

  test(
    'malformed successful JSON is an error rather than an empty dataset',
    () async {
      final client = api(
        MockClient((_) async => http.Response('<html>Oops</html>', 200)),
      );
      await expectLater(
        client.getJson(['transactions']),
        throwsFormatException,
      );
    },
  );

  test('transport errors and timeouts are surfaced without retries', () async {
    final error = http.ClientException('Offline');
    final offline = api(MockClient((_) async => throw error));
    await expectLater(offline.getJson(['transactions']), throwsA(same(error)));
    final pending = Completer<http.Response>();
    var requests = 0;
    final timeout = api(
      MockClient((_) {
        requests++;
        return pending.future;
      }),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      timeout.getJson(['transactions']),
      throwsA(isA<TimeoutException>()),
    );
    expect(requests, 1);
    pending.complete(http.Response('[]', 200));
  });

  test(
    'rejects invalid URLs, timeout values, and traversal segments',
    () async {
      for (final url in [
        'file:///tmp/test',
        'https://example.com?key=value',
        'https://user:password@example.com',
        'https://example.com#fragment',
      ]) {
        expect(
          () => api(
            MockClient((_) async => http.Response('[]', 200)),
            baseUrl: url,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => api(
          MockClient((_) async => http.Response('[]', 200)),
          timeout: Duration.zero,
        ),
        throwsArgumentError,
      );
      final client = api(MockClient((_) async => http.Response('[]', 200)));
      await expectLater(client.getJson(['..']), throwsArgumentError);
    },
  );

  test('close blocks further requests and leaves injected transport ownership intact', () async {
    final transport = _TrackingClient();
    final client = api(transport);
    client.close();
    client.close();
    expect(transport.closed, isFalse);
    await expectLater(client.getJson(['users']), throwsStateError);
  });
}

class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 200);

  @override
  void close() => closed = true;
}
