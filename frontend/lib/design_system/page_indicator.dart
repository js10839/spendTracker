import 'package:flutter/material.dart';

/// 현재 페이지의 위치를 터치 동작 없이 점으로 표시한다.
class AppPageIndicator extends StatelessWidget {
  const AppPageIndicator({super.key, required this.count, required this.activeIndex, required this.color}) : assert(count > 0), assert(activeIndex >= 0 && activeIndex < count);

  final int count;
  final int activeIndex;
  final Color color;

  @override
  /// 활성 점은 7px, 나머지는 45% 투명도의 6px 원으로 표시한다.
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index++) ...[
        if (index > 0) const SizedBox(width: 5),
        Container(
          key: ValueKey('page-indicator-dot-$index'),
          width: index == activeIndex ? 7 : 6,
          height: index == activeIndex ? 7 : 6,
          decoration: BoxDecoration(color: index == activeIndex ? color : color.withValues(alpha: .45), shape: BoxShape.circle),
        ),
      ],
    ],
  );
}
