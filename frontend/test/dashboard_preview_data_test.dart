import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/dashboard/dashboard_preview_data.dart';

void main() {
  test(
    'monthly preview includes full month and reconciles purchases and stacks',
    () {
      final chart = DashboardPreviewData.monthlySpending;
      expect(chart['start_date'], '2026-08-01');
      expect(chart['end_date'], '2026-08-31');
      final buckets = chart['buckets'] as List;
      expect(buckets, hasLength(31));
      final methods = <String>{};
      for (var day = 1; day <= 31; day++) {
        final bucket = buckets[day - 1] as Map;
        final purchases = DashboardPreviewData.transactions.where(
          (t) => t.date == DateTime(2026, 8, day),
        );
        final segments = bucket['payment_methods'] as List;
        expect(bucket['date'], '2026-08-${day.toString().padLeft(2, '0')}');
        expect(
          bucket['total_cents'],
          purchases.fold<int>(0, (sum, t) => sum + t.cents),
        );
        expect(
          bucket['total_cents'],
          segments.fold<int>(0, (sum, m) => sum + (m['total_cents'] as int)),
        );
        if (day == 7 || day == 21) {
          expect(purchases, isEmpty);
          expect(segments, isEmpty);
        } else {
          expect(purchases.length, inInclusiveRange(2, 4));
          expect(segments.length, purchases.length);
        }
        for (final segment in segments) {
          methods.add(segment['name'] as String);
          expect(segment['color'], matches(RegExp(r'^#[0-9A-F]{6}$')));
          expect(
            DashboardPreviewData.paymentMethodIds,
            contains(segment['payment_method_id']),
          );
        }
      }
      expect(methods, {'Chase', 'Amex', 'Cash', 'BofA'});
    },
  );
}
