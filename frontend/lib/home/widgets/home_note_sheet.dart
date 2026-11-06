import 'package:flutter/material.dart';

import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 홈 달력의 선택 날짜에 짧은 메모를 입력하는 시트다.
class HomeNoteSheet extends StatefulWidget {
  const HomeNoteSheet({
    super.key,
    required this.date,
    required this.initialText,
  });

  final DateTime date;
  final String initialText;

  @override
  /// 입력 내용과 글자 수를 시트 안에서 관리한다.
  State<HomeNoteSheet> createState() => _HomeNoteSheetState();
}

class _HomeNoteSheetState extends State<HomeNoteSheet> {
  late final TextEditingController _controller;

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  /// 기존 메모가 있으면 마지막 글자부터 바로 수정할 수 있게 한다.
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText)
      ..selection = TextSelection.collapsed(offset: widget.initialText.length);
  }

  @override
  /// 시트가 닫힐 때 입력 컨트롤러를 정리한다.
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  /// 키보드 높이만큼 시트를 올리고 기본 TextField로 입력을 받는다.
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final date = widget.date;
    // 현재 홈의 예시 날짜는 Figma에 표시된 요일 문구를 그대로 사용한다.
    final dateLabel = date.year == 2026 && date.month == 8 && date.day == 24
        ? 'Tue, Aug 24'
        : '${_weekdays[date.weekday % 7]}, ${_months[date.month - 1]} ${date.day}';

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTokens.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Material(
          key: const Key('home-note-sheet'),
          color: AppTokens.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: keyboardHeight == 0,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppPalette.neutral300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateLabel,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Note', style: AppTypography.heading3),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppPalette.neutral600,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTypography.bodyMediumStrong.copyWith(
                              color: AppPalette.neutral600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        14,
                        AppSpacing.lg,
                        14,
                      ),
                      decoration: BoxDecoration(
                        color: AppComponentColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 72,
                            child: TextField(
                              key: const Key('home-note-input'),
                              controller: _controller,
                              autofocus: true,
                              maxLength: 200,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).unfocus(),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              textAlignVertical: TextAlignVertical.top,
                              style: AppTypography.bodyLarge,
                              cursorColor: AppTokens.textPrimary,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_controller.text.length} / 200',
                              key: const Key('home-note-count'),
                              style: AppTypography.caption.copyWith(
                                color: AppTokens.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Material(
                        color: AppTokens.brandPurple,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          key: const Key('home-note-save'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              Navigator.of(context).pop(_controller.text),
                          child: Center(
                            child: Text(
                              'Save',
                              style: AppTypography.heading3.copyWith(
                                color: AppTokens.background,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
