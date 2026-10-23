import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';
import 'typography.dart';

enum AppButtonVariant { primary, secondary, social, outline, disabled, danger }

enum AppChipTone { income, expense, neutral, outline }

enum AppCodeDigitState { empty, active, filled }

enum AppNotificationType { cardClosing, payday, receiptScans }

enum AppCardBadgeSize { small, medium, large }

enum AppInfoCardTone { brand, income, warning, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  @override
  /// 버튼의 상태별 색을 Figma 변형에 맞춰 표시한다.
  Widget build(BuildContext context) {
    final disabled = variant == AppButtonVariant.disabled || onPressed == null;
    final color = switch (variant) {
      AppButtonVariant.primary => AppTokens.brandLime,
      AppButtonVariant.secondary => AppComponentColors.brandSubtle,
      AppButtonVariant.social => AppTokens.background,
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.disabled => AppComponentColors.borderSubtle,
      AppButtonVariant.danger => AppComponentColors.dangerSubtle,
    };
    final textColor = switch (variant) {
      AppButtonVariant.social => AppTokens.textPrimary,
      AppButtonVariant.outline => AppTokens.textPrimary,
      AppButtonVariant.disabled => AppComponentColors.disabledText,
      AppButtonVariant.secondary => AppTokens.textAccent,
      AppButtonVariant.danger => AppComponentColors.dangerText,
      _ => AppTokens.textPrimary,
    };
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: disabled ? null : onPressed,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelButton.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  /// 입력값과 실제 포커스에 따라 Figma의 기본·집중·입력 완료 상태를 표시한다.
  Widget build(BuildContext context) => Focus(
    child: Builder(
      builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: AppTokens.textSecondary,
            ),
            filled: true,
            fillColor: focused
                ? AppTokens.background
                : AppComponentColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            constraints: const BoxConstraints(minHeight: 60),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                color: AppPalette.purple500,
                width: 2,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class AppCodeDigit extends StatelessWidget {
  const AppCodeDigit({
    super.key,
    this.state = AppCodeDigitState.empty,
    this.digit,
  });

  final AppCodeDigitState state;
  final String? digit;

  @override
  /// 인증번호 한 칸의 빈칸·활성·입력 상태를 그린다.
  Widget build(BuildContext context) => Container(
    width: 53,
    height: 60,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: state == AppCodeDigitState.active
          ? AppTokens.background
          : AppComponentColors.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
    ),
    child: state == AppCodeDigitState.active
        ? Container(width: 2, height: 26, color: AppPalette.purple500)
        : state == AppCodeDigitState.filled
        ? Text(digit ?? '', style: AppTypography.heading1)
        : null,
  );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.tone = AppChipTone.neutral,
    this.onTap,
  });

  final String label;
  final AppChipTone tone;
  final VoidCallback? onTap;

  @override
  /// 분류와 결제수단에 쓸 칩의 의미별 색을 적용한다.
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AppChipTone.income => AppTokens.brandLime,
      AppChipTone.expense => AppComponentColors.brandSubtle,
      AppChipTone.neutral => AppComponentColors.surface,
      AppChipTone.outline => AppTokens.background,
    };
    final textColor = switch (tone) {
      AppChipTone.income => AppTokens.textPrimary,
      AppChipTone.expense => AppTokens.textAccent,
      AppChipTone.neutral || AppChipTone.outline => AppTokens.textBody,
    };
    return Material(
      color: color,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMedium.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  /// 온보딩 상단의 원형 뒤로 가기 SVG를 원본 크기로 표시한다.
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '뒤로 가기',
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: SvgPicture.asset('assets/icons/back.svg', width: 36, height: 36),
    ),
  );
}

class AppProgress extends StatelessWidget {
  const AppProgress({super.key, required this.step, this.totalSteps = 3});

  final int step;
  final int totalSteps;

  @override
  /// 화면 너비에 맞춰 진행률을 그려 작은 기기에서도 넘치지 않게 한다.
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: (step / totalSteps).clamp(0.0, 1.0),
      minHeight: 5,
      backgroundColor: AppComponentColors.borderSubtle,
      valueColor: const AlwaysStoppedAnimation(AppTokens.brandLime),
    ),
  );
}

class AppOption extends StatelessWidget {
  const AppOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  /// 온보딩 선택지를 선택 상태에 따라 강조한다.
  Widget build(BuildContext context) => Material(
    color: selected ? AppTokens.brandLime : AppComponentColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      side: BorderSide.none,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selected
                  ? AppTypography.bodyLargeStrong
                  : AppTypography.bodyLarge.copyWith(color: AppTokens.textBody),
            ),
          ),
        ),
      ),
    ),
  );
}

class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels = const ['Simple', 'Detail'],
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  @override
  /// 선택된 보기 모드를 흰색 캡슐로 표시한다.
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppComponentColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selectedIndex == i
                    ? AppTokens.background
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: selectedIndex == i
                    ? const [
                        BoxShadow(
                          color: Color(0x1E141E16),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                style: AppTypography.labelMedium.copyWith(
                  color: selectedIndex == i
                      ? AppTokens.textPrimary
                      : AppTokens.textSecondary,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class AppNotification extends StatelessWidget {
  const AppNotification({
    super.key,
    required this.title,
    required this.body,
    required this.meta,
    required this.type,
    this.unread = false,
    this.onTap,
  });

  final String title;
  final String body;
  final String meta;
  final AppNotificationType type;
  final bool unread;
  final VoidCallback? onTap;

  @override
  /// 알림 종류에 맞는 아이콘과 읽지 않음 표시를 원본 자산으로 배치한다.
  Widget build(BuildContext context) {
    final iconColor = switch (type) {
      AppNotificationType.cardClosing => AppComponentColors.brandSubtle,
      AppNotificationType.payday => AppComponentColors.incomeSubtle,
      AppNotificationType.receiptScans => AppComponentColors.warningSubtle,
    };
    final iconPath = switch (type) {
      AppNotificationType.cardClosing => 'assets/icons/notification_card.svg',
      AppNotificationType.payday => 'assets/icons/notification_payday.svg',
      AppNotificationType.receiptScans =>
        'assets/icons/notification_receipt.svg',
    };
    return Material(
      color: AppTokens.background,
      borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: SvgPicture.asset(iconPath, width: 20, height: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyLargeStrong),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTokens.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/icons/unread_dot.svg',
                  width: 8,
                  height: 8,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppCardBadge extends StatelessWidget {
  const AppCardBadge({
    super.key,
    required this.letter,
    this.size = AppCardBadgeSize.small,
    this.color = AppPalette.accentBlue,
  });

  final String letter;
  final AppCardBadgeSize size;
  final Color color;

  @override
  /// 카드 색상과 한 글자를 Figma의 세 크기로 표시한다.
  Widget build(BuildContext context) {
    final dimension = switch (size) {
      AppCardBadgeSize.small => 16.0,
      AppCardBadgeSize.medium => 24.0,
      AppCardBadgeSize.large => 40.0,
    };
    final radius = switch (size) {
      AppCardBadgeSize.small => 5.0,
      AppCardBadgeSize.medium => 7.0,
      AppCardBadgeSize.large => 12.0,
    };
    final style = switch (size) {
      AppCardBadgeSize.small => AppTypography.caption,
      AppCardBadgeSize.medium => AppTypography.bodyMediumStrong,
      AppCardBadgeSize.large => AppTypography.heading3,
    };
    return Container(
      width: dimension,
      height: dimension,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        letter,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: style.copyWith(color: AppTokens.background),
      ),
    );
  }
}

class AppInfoCard extends StatelessWidget {
  const AppInfoCard({
    super.key,
    required this.title,
    required this.body,
    this.tone = AppInfoCardTone.brand,
  });

  final String title;
  final String body;
  final AppInfoCardTone tone;

  @override
  /// 정보 카드의 네 가지 톤에 따라 배경과 제목 색을 함께 바꾼다.
  Widget build(BuildContext context) {
    final backgroundColor = switch (tone) {
      AppInfoCardTone.brand => AppComponentColors.brandSubtle,
      AppInfoCardTone.income => AppComponentColors.incomeSubtle,
      AppInfoCardTone.warning => AppComponentColors.warningSubtle,
      AppInfoCardTone.danger => AppComponentColors.dangerSubtle,
    };
    final titleColor = switch (tone) {
      AppInfoCardTone.brand => AppTokens.textAccent,
      AppInfoCardTone.income => AppComponentColors.incomeText,
      AppInfoCardTone.warning => AppTokens.textPrimary,
      AppInfoCardTone.danger => AppComponentColors.dangerText,
    };
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLargeStrong.copyWith(color: titleColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodyMedium.copyWith(color: AppTokens.textBody),
          ),
        ],
      ),
    );
  }
}

class AppToast extends StatelessWidget {
  const AppToast({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  /// 짧은 완료 메시지와 되돌리기 등 한 가지 동작을 표시한다.
  Widget build(BuildContext context) => Material(
    color: AppTokens.textPrimary,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMediumStrong.copyWith(
                  color: AppTokens.background,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            InkWell(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: AppTypography.labelMedium.copyWith(
                  color: AppTokens.background,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
