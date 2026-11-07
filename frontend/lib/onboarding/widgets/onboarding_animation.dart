import 'dart:async';

import 'package:flutter/material.dart';

/// 온보딩 GIF를 표시하고 필요한 경우 첫 재생이 끝난 뒤 진행한다.
class OnboardingAnimation extends StatefulWidget {
  const OnboardingAnimation({super.key, required this.asset, required this.width, required this.height, this.lastFrame, this.onComplete, this.cropSetup = false});

  final String asset;
  final double width, height;
  final int? lastFrame;
  final VoidCallback? onComplete;
  final bool cropSetup;

  @override
  State<OnboardingAnimation> createState() => _OnboardingAnimationState();
}

class _OnboardingAnimationState extends State<OnboardingAnimation> {
  Timer? _completionTimer;

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  /// 마지막 프레임의 원본 표시 시간이 지난 후 한 번만 이동한다.
  void _finishAfterLastFrame() {
    if (_completionTimer != null || widget.onComplete == null) return;
    _completionTimer = Timer(const Duration(milliseconds: 30), () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(widget.asset, fit: BoxFit.contain, frameBuilder: (context, child, frame, loaded) {
      if (frame != null && widget.lastFrame != null && frame >= widget.lastFrame!) _finishAfterLastFrame();
      return child;
    });
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.cropSetup
          ? ClipRect(child: OverflowBox(alignment: Alignment.topCenter, minWidth: 240, maxWidth: 240, minHeight: 312, maxHeight: 312, child: image))
          : image,
    );
  }
}
