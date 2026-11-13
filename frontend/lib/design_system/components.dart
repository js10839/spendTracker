import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';
import 'typography.dart';

export 'calendar.dart';
export 'bottom_navigation.dart';
export 'category_icon.dart';
export 'chevron.dart';
export 'tooltip.dart';

enum AppButtonVariant { primary, secondary, social, outline, surface, disabled, danger }

enum AppButtonLabelStyle { standard, regular }

enum AppInputStyle { standard, onboardingEmail, cardName }

enum AppSocialLogo { google, apple }

enum AppChipTone { income, expense, neutral, outline }

enum AppChipSize { regular, compact }

enum AppSegmentedControlTone { neutral, onColor, onLightColor }

enum AppCodeDigitState { empty, active, filled }

enum AppNotificationType { cardClosing, payday, receiptScans }

enum AppCardBadgeSize { small, medium, large }

enum AppInfoCardTone { neutral, brand, income, warning, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.socialLogo,
    this.labelStyle = AppButtonLabelStyle.standard,
    this.disabledBackgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppSocialLogo? socialLogo;
  final AppButtonLabelStyle labelStyle;
  final Color? disabledBackgroundColor;

  @override
  /// 버튼의 상태별 색을 Figma 변형에 맞춰 표시한다.
  Widget build(BuildContext context) {
    final disabled = variant == AppButtonVariant.disabled || onPressed == null;
    final color = switch (variant) {
      AppButtonVariant.primary => AppTokens.brandLime,
      AppButtonVariant.secondary => AppTokens.brandPurple,
      AppButtonVariant.social => AppTokens.surface,
      AppButtonVariant.outline => AppTokens.surface,
      AppButtonVariant.surface => AppTokens.surface,
      AppButtonVariant.disabled => disabledBackgroundColor ?? AppTokens.borderSubtle,
      AppButtonVariant.danger => AppTokens.statusDanger,
    };
    final textColor = switch (variant) {
      AppButtonVariant.social => AppTokens.textPrimary,
      AppButtonVariant.outline => AppTokens.textBody,
      AppButtonVariant.surface => AppTokens.textPrimary,
      AppButtonVariant.disabled => AppTokens.textDisabled,
      AppButtonVariant.secondary => AppTokens.textInverse,
      AppButtonVariant.danger => AppTokens.textInverse,
      _ => AppTokens.textPrimary,
    };
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: disabled ? null : onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (variant == AppButtonVariant.social &&
                    socialLogo != null) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: SvgPicture.asset(
                      socialLogo == AppSocialLogo.google
                          ? 'assets/icons/google.svg'
                          : 'assets/icons/apple.svg',
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (labelStyle == AppButtonLabelStyle.regular
                                ? AppTypography.bodyLarge
                                : AppTypography.labelButton)
                            .copyWith(color: textColor),
                  ),
                ),
              ],
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
    this.inputStyle = AppInputStyle.standard,
    this.hasError = false,
    this.inputFormatters,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final AppInputStyle inputStyle;
  final bool hasError;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  @override
  /// 입력값과 실제 포커스에 따라 Figma의 기본·집중·입력 완료 상태를 표시한다.
  Widget build(BuildContext context) => Focus(
    child: Builder(
      builder: (context) {
        final focused = Focus.of(context).hasFocus;
        final email = inputStyle == AppInputStyle.onboardingEmail;
        final cardName = inputStyle == AppInputStyle.cardName;
        return TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: email ? AppTokens.textDisabled : AppTokens.textSecondary,
            ),
            filled: true,
            fillColor: email || cardName || focused ? AppTokens.background : AppTokens.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: email ? AppSpacing.twoXL : AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            constraints: BoxConstraints(minHeight: email ? 56 : 60, maxHeight: email ? 56 : double.infinity),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(email ? AppRadius.xl : AppRadius.md),
              borderSide: email || cardName ? BorderSide(color: hasError ? AppTokens.statusDanger : AppTokens.borderStrong) : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(email ? AppRadius.xl : AppRadius.md),
              borderSide: BorderSide(
                color: hasError ? AppTokens.statusDanger : AppPalette.purple500,
                width: 1.5,
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
          : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      border: state == AppCodeDigitState.active
          ? Border.all(color: AppTokens.brandPurple, width: 1.5)
          : null,
    ),
    child: state == AppCodeDigitState.active
        ? Container(width: 2, height: 26, color: AppPalette.purple500)
        : state == AppCodeDigitState.filled
        ? Text(digit ?? '', style: AppTypography.heading2)
        : null,
  );
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.tone = AppChipTone.neutral,
    this.size = AppChipSize.regular,
    this.leadingColor,
    this.onTap,
  });

  final String label;
  final AppChipTone tone;
  final AppChipSize size;
  final Color? leadingColor;
  final VoidCallback? onTap;

  @override
  /// 기본 칩은 유지하고 거래 요약에는 작은 글자와 카드 색 점을 적용한다.
  Widget build(BuildContext context) {
    final compact = size == AppChipSize.compact;
    final color = switch (tone) {
      AppChipTone.income => AppTokens.brandLime,
      AppChipTone.expense => AppTokens.brandPurple,
      AppChipTone.neutral || AppChipTone.outline => AppTokens.surface,
    };
    final textColor = switch (tone) {
      AppChipTone.income => AppTokens.textPrimary,
      AppChipTone.expense => AppTokens.textInverse,
      AppChipTone.neutral || AppChipTone.outline => AppTokens.textPrimary,
    };
    return Material(
      color: color,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (compact
                            ? AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w400,
                              )
                            : AppTypography.labelMedium)
                        .copyWith(color: textColor),
              ),
            ],
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
  const AppProgress({super.key, required this.step, this.totalSteps = 3, this.animateOnAppear = false, this.initialStep});

  final int step;
  final int totalSteps;
  final bool animateOnAppear;
  final int? initialStep;

  @override
  /// 단계가 바뀌면 이전 진행률에서 새 진행률까지 부드럽게 이동한다.
  Widget build(BuildContext context) {
    final progress = (step / totalSteps).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: initialStep == null ? (animateOnAppear ? 0.0 : progress) : (initialStep! / totalSteps).clamp(0.0, 1.0), end: progress),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, value, child) => LinearProgressIndicator(
          value: value,
          minHeight: 5,
          backgroundColor: AppTokens.surface,
          valueColor: const AlwaysStoppedAnimation(AppTokens.brandLime),
        ),
      ),
    );
  }
}

enum AppOptionStyle { standard, onboardingCard }

class AppOption extends StatelessWidget {
  const AppOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.style = AppOptionStyle.standard,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppOptionStyle style;

  @override
  /// 온보딩 선택지를 선택 상태에 따라 강조한다.
  Widget build(BuildContext context) => Material(
    color: selected ? AppTokens.brandLime : (style == AppOptionStyle.onboardingCard ? AppTokens.surface : AppTokens.background),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      side: BorderSide.none,
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      overlayColor: style == AppOptionStyle.onboardingCard
          ? const WidgetStatePropertyAll(Colors.transparent)
          : null,
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
              style: style == AppOptionStyle.onboardingCard
                  ? (selected ? AppTypography.bodyLarge : AppTypography.bodyMedium)
                  : (selected ? AppTypography.bodyLargeStrong : AppTypography.labelMedium),
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
    this.tone = AppSegmentedControlTone.neutral,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  final AppSegmentedControlTone tone;

  @override
  /// 컬러 헤더에서는 Figma의 반투명 1.2px 테두리와 흰 선택 캡슐을 표시한다.
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    height: tone != AppSegmentedControlTone.neutral ? 30 : null,
    width: tone != AppSegmentedControlTone.neutral ? 136 : null,
    decoration: BoxDecoration(
      color: tone != AppSegmentedControlTone.neutral
          ? AppTokens.background.withValues(alpha: 0.18)
          : AppComponentColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: tone != AppSegmentedControlTone.neutral
          ? Border.all(
              color: AppTokens.background.withValues(alpha: 0.55),
              width: 1.2,
            )
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          if (tone != AppSegmentedControlTone.neutral)
            Expanded(child: _segment(i))
          else
            _segment(i),
      ],
    ),
  );

  /// 배경 톤에 따른 선택 캡슐과 텍스트 색을 적용한다.
  Widget _segment(int i) => GestureDetector(
    onTap: () => onChanged(i),
    child: Container(
      alignment: Alignment.center,
      padding: tone != AppSegmentedControlTone.neutral
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selectedIndex == i ? AppTokens.background : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: selectedIndex != i
            ? null
            : tone != AppSegmentedControlTone.neutral
            ? [
                BoxShadow(
                  color: AppComponentColors.shadowPurple.withValues(
                    alpha: 45 / 255,
                  ),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x1E141E16),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Text(
        labels[i],
        style:
            (tone != AppSegmentedControlTone.neutral
                    ? AppTypography.caption.copyWith(
                        fontWeight: selectedIndex == i
                            ? FontWeight.w500
                            : FontWeight.w400,
                      )
                    : AppTypography.labelMedium)
                .copyWith(
                  color: selectedIndex == i
                      ? AppTokens.textPrimary
                      : tone == AppSegmentedControlTone.onColor
                      ? AppTokens.textInverse.withValues(alpha: 0.55)
                      : tone == AppSegmentedControlTone.onLightColor
                      ? AppTokens.textPrimary.withValues(alpha: 0.55)
                      : AppTokens.textSecondary,
                ),
      ),
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
  /// 알림 종류에 맞는 아이콘과 읽지 않음 표시를 Figma의 공통 표면에 배치한다.
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.background,
      borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTokens.surface,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: switch (type) {
                  AppNotificationType.cardClosing => Container(
                    width: 22,
                    height: 15,
                    decoration: BoxDecoration(
                      color: AppPalette.accentBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AppNotificationType.payday => Text(
                    '+\$',
                    style: AppTypography.bodyLargeStrong.copyWith(
                      color: AppTokens.brandPurple,
                    ),
                  ),
                  AppNotificationType.receiptScans => SvgPicture.asset(
                    'assets/icons/notification_document.svg',
                  ),
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.bodyLargeStrong),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textDisabled,
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
    this.tone = AppInfoCardTone.neutral,
  });

  final String title;
  final String body;
  final AppInfoCardTone tone;

  @override
  /// 정보 카드의 네 가지 톤에 따라 배경과 제목 색을 함께 바꾼다.
  Widget build(BuildContext context) {
    final backgroundColor = tone == AppInfoCardTone.warning
        ? AppComponentColors.warningSubtle
        : AppTokens.surface;
    final titleColor = switch (tone) {
      AppInfoCardTone.neutral => AppTokens.textPrimary,
      AppInfoCardTone.brand => AppTokens.textAccent,
      AppInfoCardTone.income => AppTokens.textPrimary,
      AppInfoCardTone.warning => AppTokens.textPrimary,
      AppInfoCardTone.danger => AppTokens.statusDanger,
    };
    return Container(
      width: double.infinity,
      constraints: tone == AppInfoCardTone.warning
          ? const BoxConstraints(minHeight: 80)
          : null,
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
            style:
                (tone == AppInfoCardTone.warning
                        ? AppTypography.bodyLargeStrong
                        : AppTypography.labelMedium)
                    .copyWith(color: titleColor),
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
                  color: AppTokens.textInverse,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            InkWell(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: AppTypography.labelMedium.copyWith(
                  color: AppTokens.textInverse,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
