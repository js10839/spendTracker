import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';

/// 거래 품목에서 카테고리를 피그마의 13px 아이콘으로 표시한다.
class AppCategoryIcon extends StatelessWidget {
  const AppCategoryIcon({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    if (category == 'Living') {
      return SizedBox(
        width: 13,
        height: 13,
        child: Stack(
          children: [
            Positioned(
              left: 3.25,
              top: 4.33,
              child: Container(
                width: 6.5,
                height: 8.125,
                decoration: BoxDecoration(
                  color: AppPalette.neutral600,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: 4.88,
              top: 1.63,
              child: Container(
                width: 3.25,
                height: 3.25,
                decoration: BoxDecoration(
                  color: AppPalette.neutral600,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            Positioned(
              left: 5.69,
              top: .27,
              child: Container(
                width: 1.625,
                height: 1.625,
                decoration: BoxDecoration(
                  color: AppPalette.neutral600,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final asset = switch (category) {
      'Food' => 'imgDayFood.svg',
      'Dining' => 'imgDayDining.svg',
      'Transport' => 'imgDayTransport.svg',
      'Tax & Tip' => 'imgDayTax.svg',
      _ => null,
    };
    if (asset == null) {
      return const Icon(
        Icons.category_outlined,
        size: 13,
        color: AppPalette.neutral600,
      );
    }
    return SvgPicture.asset('assets/home/$asset', width: 13, height: 13);
  }
}
