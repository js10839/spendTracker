import '../../core/api_client.dart';

/// 결제수단 저장을 화면에서 분리한다.
abstract class PaymentMethodRepository {
  static PaymentMethodRepository instance = const UnconfiguredPaymentMethodRepository();

  /// 신용카드 한 장을 현재 사용자의 지갑에 저장한다.
  Future<void> createCreditCard({required String name, required int closingDay, required String color});
}

/// API가 설정되지 않은 경우 저장 오류를 전달한다.
class UnconfiguredPaymentMethodRepository implements PaymentMethodRepository {
  const UnconfiguredPaymentMethodRepository();

  @override
  Future<void> createCreditCard({required String name, required int closingDay, required String color}) async => throw StateError('API is not configured');
}

/// 인증된 FastAPI 요청으로 신용카드를 저장한다.
class ApiPaymentMethodRepository implements PaymentMethodRepository {
  const ApiPaymentMethodRepository(this.api);
  final ApiClient api;

  @override
  Future<void> createCreditCard({required String name, required int closingDay, required String color}) async {
    await api.post('/users/me/payment-methods', body: {'name': name, 'type': 'credit', 'closing_day': closingDay, 'color': color});
  }
}
