import '../../calendar/calendar_dates.dart';

/// 서버 검색 결과의 품목과 일치한 필드다.
class TransactionSearchItem {
  TransactionSearchItem.fromJson(Map<String, dynamic> json)
      : transactionId = json['transaction_id'] as String,
        name = json['name'] as String,
        merchant = json['merchant'] as String?,
        category = json['category_name'] as String,
        date = parseCalendarDate(json['transacted_at'] as String),
        cents = json['amount_cents'] as int,
        matchedFields = (json['matched_fields'] as List).cast<String>();
  final String transactionId, name, category;
  final String? merchant;
  final DateTime date;
  final int cents;
  final List<String> matchedFields;
}

/// 서버가 제공한 검색 합계와 일치 날짜를 그대로 보관한다.
class TransactionSearchResult {
  TransactionSearchResult.fromJson(Map<String, dynamic> json)
      : dates = (json['matched_dates'] as List).map((date) => parseCalendarDate(date as String)).toSet(),
        itemCount = json['item_count'] as int,
        storeCount = json['store_count'] as int,
        totalCents = json['matched_items_total_cents'] as int,
        items = (json['items'] as List).map((item) => TransactionSearchItem.fromJson(item as Map<String, dynamic>)).toList();
  final Set<DateTime> dates;
  final int itemCount, storeCount, totalCents;
  final List<TransactionSearchItem> items;
}
