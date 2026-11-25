import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 인접 기간이 준비된 방향으로 달력을 손가락에 맞춰 넘긴다.
class AppCalendarPager extends StatefulWidget {
  const AppCalendarPager({super.key, required this.current, required this.currentHeight, required this.onMove, this.previous, this.previousHeight, this.next, this.nextHeight});
  final Widget current;
  final double currentHeight;
  final Widget? previous, next;
  final double? previousHeight, nextHeight;
  final ValueChanged<int> onMove;

  @override
  State<AppCalendarPager> createState() => AppCalendarPagerState();
}

class AppCalendarPagerState extends State<AppCalendarPager> {
  final _controller = PageController(initialPage: 1);
  int _settled = 1;
  Offset _dragDelta = Offset.zero;

  /// 미리 조회되지 않은 방향을 밀면 화면을 유지하며 조회를 요청한다.
  void _retryMissing(PointerUpEvent event) {
    if (_dragDelta.dx.abs() <= kTouchSlop * 2 || _dragDelta.dx.abs() <= _dragDelta.dy.abs() * 1.5) return;
    if (_dragDelta.dx > 0 && widget.previous == null) widget.onMove(-1);
    if (_dragDelta.dx < 0 && widget.next == null) widget.onMove(1);
  }

  /// 화살표와 스와이프가 같은 페이지 전환을 사용한다.
  Future<void> move(int direction) async {
    if (!_controller.hasClients) return;
    final target = direction < 0 ? 0 : 2;
    if ((target == 0 && widget.previous == null) || (target == 2 && widget.next == null)) {
      widget.onMove(direction);
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
      _finish(target);
    } else {
      await _controller.animateToPage(target, duration: kThemeAnimationDuration, curve: Curves.easeOut);
    }
  }

  /// 전환이 끝난 뒤 현재 기간을 교체하고 중앙 페이지로 되돌린다.
  void _finish(int page) {
    if (page == 1 || _settled != 1) return;
    _settled = page;
    widget.onMove(page == 0 ? -1 : 1);
    _controller.jumpToPage(1);
    _settled = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  /// 현재 높이를 유지하면서 인접 달력의 넘치는 부분은 잘라 보여준다.
  Widget build(BuildContext context) => SizedBox(
    height: widget.currentHeight,
    child: NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 && _controller.hasClients) _finish(_controller.page!.round());
        return false;
      },
      // 세로 페이지 스크롤이 수평 전환보다 먼저 제스처를 인식하도록 한다.
      child: Listener(
        onPointerDown: (_) => _dragDelta = Offset.zero,
        onPointerMove: (event) => _dragDelta += event.delta,
        onPointerUp: _retryMissing,
        child: MediaQuery(
        data: MediaQuery.of(context).copyWith(gestureSettings: DeviceGestureSettings(touchSlop: (MediaQuery.of(context).gestureSettings.touchSlop ?? kTouchSlop) * 1.5)),
        child: PageView.builder(
        // Scrollable은 physics의 타입이 같으면 설정값 변경을 반영하지 않는다.
        key: ValueKey('${widget.previous != null}-${widget.next != null}'),
        controller: _controller,
        itemCount: 3,
        physics: _CalendarSwipePhysics(previous: widget.previous != null, next: widget.next != null, parent: const PageScrollPhysics()),
        itemBuilder: (context, index) {
          final child = index == 0 ? widget.previous : index == 2 ? widget.next : widget.current;
          final height = index == 0 ? widget.previousHeight : index == 2 ? widget.nextHeight : widget.currentHeight;
          if (child == null) return const SizedBox.shrink();
          return ClipRect(child: OverflowBox(alignment: Alignment.topCenter, minHeight: height, maxHeight: height, child: child));
        },
        ),
        ),
      ),
    ),
  );
}

/// 미리 조회하지 못한 방향으로는 현재 페이지를 벗어나지 않는다.
class _CalendarSwipePhysics extends ScrollPhysics {
  const _CalendarSwipePhysics({required this.previous, required this.next, super.parent});
  final bool previous, next;

  @override
  _CalendarSwipePhysics applyTo(ScrollPhysics? ancestor) => _CalendarSwipePhysics(previous: previous, next: next, parent: buildParent(ancestor));

  @override
  /// 데이터가 없는 쪽은 경계로 제한하고 다른 제스처는 기본 물리를 따른다.
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final center = position.viewportDimension;
    if (!previous && value < center && position.pixels >= center) return value - center;
    if (!next && value > center && position.pixels <= center) return value - center;
    return super.applyBoundaryConditions(position, value);
  }
}
