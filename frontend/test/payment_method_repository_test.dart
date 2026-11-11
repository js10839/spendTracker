import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/core/api_client.dart';
import 'package:spending_tracker/data/payment_methods/payment_method_repository.dart';
import 'package:spending_tracker/onboarding/onboarding_card_color.dart';

void main() {
  test('카드 API에 인증 토큰과 실제 요청 형식을 전달한다', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/users/me/payment-methods');
      expect(request.headers['authorization'], 'Bearer token');
      expect(jsonDecode(request.body), {'name': 'Chase', 'type': 'credit', 'closing_day': 15, 'color': '#5A8BFC'});
      return http.Response('{"id":"card","name":"Chase","type":"credit","closing_day":15,"color":"#5A8BFC"}', 201);
    });
    final repository = ApiPaymentMethodRepository(ApiClient(baseUri: Uri.parse('https://example.com'), accessToken: () => 'token', client: client));
    await repository.createCreditCard(name: 'Chase', closingDay: 15, color: onboardingCardColor('Chase'));
  });

  test('은행별 색상은 승인된 공통 토큰을 사용한다', () {
    expect([for (final name in ['Chase', 'Amex', 'Capital One', 'Citi']) onboardingCardColor(name)], everyElement('#5A8BFC'));
    expect(onboardingCardColor('Discover'), '#FCA05A');
    expect(onboardingCardColor('Apple Card'), '#F6F7F6');
    expect(onboardingCardColor('Bank of America'), '#FC5A5A');
    expect(onboardingCardColor('Wells Fargo'), '#FC5A5A');
    expect(onboardingCardColor('My card'), '#EBEEEC');
  });
}
