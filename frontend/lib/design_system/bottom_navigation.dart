import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';
import 'typography.dart';

/// 주요 화면에서 공유할 하단 탐색 표시를 담당한다.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    this.onSelected,
    this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final VoidCallback? onAdd;

  @override
  /// 가운데 추가 버튼과 네 개의 화면 탭을 같은 간격으로 배치한다.
  Widget build(BuildContext context) => Container(
    height: 66,
    decoration: const BoxDecoration(
      color: AppTokens.background,
      border: Border(top: BorderSide(color: AppTokens.borderSubtle)),
    ),
    child: Row(
      children: [
        _tab(0, 'Home', 'imgHome4HomeHouseRoofShelter.svg'),
        _tab(
          1,
          'Dashboard',
          'imgSignalFullPhoneMobileDeviceSignalWirelessSmartphoneIphoneBarBarsFullAndroid.svg',
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 54,
              height: 54,
              child: Material(
                color: AppTokens.brandLime,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAdd,
                  child: const Icon(
                    Icons.add,
                    size: 27,
                    color: AppTokens.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        _tab(3, 'Wallet', 'imgWalletMoneyPaymentFinanceWallet.svg'),
        _tab(
          4,
          'Profile',
          'imgUserMultipleGroupCloseGeometricHumanMultiplePersonUpUser.svg',
        ),
      ],
    ),
  );

  /// 선택된 탭의 색을 강조하고 화면 이동은 호출자에게 맡긴다.
  Widget _tab(int index, String label, String icon) => Expanded(
    child: InkWell(
      onTap: onSelected == null ? null : () => onSelected!(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/home/$icon',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              index == selectedIndex
                  ? AppTokens.brandPurple
                  : AppTokens.textSecondary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: index == selectedIndex
                  ? AppTokens.brandPurple
                  : AppTokens.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
