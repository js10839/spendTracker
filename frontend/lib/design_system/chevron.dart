import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 피그마의 26px 터치 영역 안에 아래 방향 화살표를 가운데 배치한다.
class AppChevronDown extends StatelessWidget {
  const AppChevronDown({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 26,
    child: Center(child: SvgPicture.asset('assets/home/imgDaySummaryChevron.svg')),
  );
}
