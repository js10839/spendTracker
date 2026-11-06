import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 온보딩 영상을 재생하고 재생이 끝나면 다음 동작을 실행한다.
class OnboardingVideo extends StatefulWidget {
  const OnboardingVideo({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    this.onComplete,
    this.cropTop = false,
    this.loop = false,
  });

  final String asset;
  final double width;
  final double height;
  final VoidCallback? onComplete;
  final bool cropTop;
  final bool loop;

  @override
  State<OnboardingVideo> createState() => _OnboardingVideoState();
}

class _OnboardingVideoState extends State<OnboardingVideo> {
  late final VideoPlayerController _controller;
  bool _completed = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.asset)
      ..addListener(_onVideoChanged);
    _initialize();
  }

  /// 영상 준비 후 소리 없이 한 번 재생한다.
  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setVolume(0);
      if (!mounted) return;
      await _controller.setLooping(widget.loop);
      if (!mounted) return;
      await _controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  /// 재생이 끝나면 한 번만 화면 전환을 요청한다.
  void _onVideoChanged() {
    final value = _controller.value;
    if (value.hasError) {
      if (mounted && !_error) setState(() => _error = true);
      return;
    }
    if (!widget.loop &&
        !_completed &&
        value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _completed = true;
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: _error
        ? Center(
            child: widget.onComplete == null
                ? const SizedBox()
                : TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Continue'),
                  ),
          )
        : !_controller.value.isInitialized
        ? const SizedBox()
        : widget.cropTop
        ? ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: 370,
              maxWidth: 370,
              minHeight: 337,
              maxHeight: 337,
              child: VideoPlayer(_controller),
            ),
          )
        : FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
  );
}
