import 'package:flutter/material.dart';

import '../calendar/calendar_models.dart';
import '../design_system/tokens.dart';
import 'home_preview_data.dart';

/// 거래 위젯이 데이터 출처와 관계없이 표시할 결제수단이다.
class HomeTransactionMethod {
  const HomeTransactionMethod(this.id, this.name, this.color, {this.previewAsset});
  final String id, name;
  final Color color;
  final String? previewAsset;
}

/// 거래 위젯에 필요한 품목 표시 정보다.
class HomeTransactionItem {
  const HomeTransactionItem(this.name, this.category, this.cents);
  final String name;
  final String? category;
  final int cents;
}

/// API 거래와 예시 거래가 공유하는 화면 표시 모델이다.
class HomeTransactionData {
  const HomeTransactionData({required this.id, required this.merchant, required this.method, required this.cents, required this.itemCount, required this.items, this.memo});
  final String id, merchant;
  final HomeTransactionMethod method;
  final int cents, itemCount;
  final List<HomeTransactionItem> items;
  final String? memo;
}

/// 기존 게스트 예시를 거래 화면의 공통 데이터로 변환한다.
List<HomeTransactionData> previewHomeTransactions(DateTime date, int card) {
  const assets = ['', 'imgDayMethodChase.svg', 'imgDayMethodAmex.svg', 'imgDayMethodCash.svg', 'imgDayMethodDebit.svg'];
  final transactions = HomePreviewData.transactionsFor(date);
  return [for (final (index, transaction) in transactions.indexed) if (card == 0 || card == transaction.card) HomeTransactionData(
    id: '$index', merchant: transaction.merchant, cents: transaction.cents, itemCount: transaction.itemCount,
    method: HomeTransactionMethod('${transaction.card}', HomePreviewData.cardNames[transaction.card], HomePreviewData.cardColors[transaction.card], previewAsset: assets[transaction.card]),
    items: [for (final item in HomePreviewData.itemsFor(transaction)) HomeTransactionItem(item.name, item.category, item.cents)],
  )];
}

/// 서버 거래의 결제수단과 카테고리를 실제 조회 결과로 연결한다.
List<HomeTransactionData> memberHomeTransactions(CalendarDay? day, List<CalendarPaymentMethod> methods, Map<String, String> categories) {
  final byId = {for (final method in methods) method.id: method};
  return [for (final transaction in day?.transactions ?? <CalendarTransaction>[]) HomeTransactionData(
    id: transaction.id, merchant: transaction.merchant?.trim().isNotEmpty == true ? transaction.merchant! : 'Expense', cents: transaction.totalCents,
    method: _memberMethod(transaction.paymentMethodId, byId[transaction.paymentMethodId]),
    itemCount: transaction.items.length, memo: transaction.memo,
    items: [
      for (final item in transaction.items) HomeTransactionItem(item.name, categories[item.categoryId], item.amountCents),
      if (transaction.taxCents != 0) HomeTransactionItem('Tax', 'Tax & Tip', transaction.taxCents),
      if (transaction.tipCents != 0) HomeTransactionItem('Tip', 'Tax & Tip', transaction.tipCents),
    ],
  )];
}

/// 서버에서 반환된 색상과 이름만 사용해 결제수단을 표현한다.
HomeTransactionMethod _memberMethod(String id, CalendarPaymentMethod? method) {
  final value = method?.color;
  final color = value != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value) ? Color(int.parse('FF${value.substring(1)}', radix: 16)) : AppTokens.textSecondary;
  return HomeTransactionMethod(id, method?.name ?? '', color);
}
