import 'package:flutter/material.dart';

import '../logibble.dart';
import 'inspector_page.dart';

/// Floats a draggable bug button over [child] that opens [LogibbleInspectorPage].
///
/// Put it in `MaterialApp.builder` so it sits above every route:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => LogibbleOverlay(child: child!),
/// )
/// ```
///
/// The button shows a dot while the latest request is in flight (amber) or
/// failed (red), hides while the inspector is open, and snaps to the nearest
/// screen edge when released. When [Logibble.enabled] is false this widget
/// returns [child] untouched.
class LogibbleOverlay extends StatefulWidget {
  /// Creates the overlay.
  const LogibbleOverlay({super.key, this.logibble, required this.child, this.navigatorKey});

  /// Key of the bubble button, for widget tests.
  static const buttonKey = Key('logibble-button');

  /// What the inspector shows. Defaults to [Logibble.instance].
  final Logibble? logibble;

  /// Usually the `child` handed to `MaterialApp.builder`.
  final Widget child;

  /// The navigator the inspector is pushed onto. When omitted, the first
  /// [Navigator] below this widget is used, which is the app's root navigator
  /// for `MaterialApp` and `MaterialApp.router` (go_router, auto_route…).
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<LogibbleOverlay> createState() => _LogibbleOverlayState();
}

class _LogibbleOverlayState extends State<LogibbleOverlay> {
  static const _size = 48.0;
  static const _margin = 8.0;

  Offset? _position;
  var _dragging = false;
  var _open = false;

  Logibble get _logibble => widget.logibble ?? Logibble.instance;

  NavigatorState? _navigator() {
    if (widget.navigatorKey?.currentState case final navigator?) return navigator;
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  Future<void> _openInspector() async {
    final navigator = _navigator();
    if (navigator == null || _open) return;
    setState(() => _open = true);
    await navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'logibble'),
        builder: (_) => LogibbleInspectorPage(logibble: _logibble),
      ),
    );
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_logibble.enabled) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final min = Offset(padding.left + _margin, padding.top + _margin);
        final max = Offset(
          constraints.maxWidth - _size - padding.right - _margin,
          constraints.maxHeight - _size - padding.bottom - _margin,
        );
        final raw = _position ?? Offset(max.dx, constraints.maxHeight * 0.62);
        final position = Offset(raw.dx.clamp(min.dx, max.dx), raw.dy.clamp(min.dy, max.dy));

        return Stack(
          children: [
            widget.child,
            if (!_open)
              AnimatedPositioned(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: position.dx,
                top: position.dy,
                child: GestureDetector(
                  key: LogibbleOverlay.buttonKey,
                  onPanStart: (_) => setState(() => _dragging = true),
                  onPanUpdate: (details) => setState(() => _position = position + details.delta),
                  onPanEnd: (_) => setState(() {
                    _dragging = false;
                    final snapLeft = position.dx + _size / 2 < constraints.maxWidth / 2;
                    _position = Offset(snapLeft ? min.dx : max.dx, position.dy);
                  }),
                  onTap: _openInspector,
                  child: Semantics(
                    button: true,
                    label: 'Open debug inspector',
                    child: ListenableBuilder(
                      listenable: _logibble,
                      builder: (context, _) => _Bubble(size: _size, dot: _dotColor()),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color? _dotColor() {
    final latest = _logibble.entries.firstOrNull;
    if (latest == null || latest.isSuccess) return null;
    return latest.isPending ? Colors.amber : Colors.redAccent;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.dot});

  final double size;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF26231F),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.bug_report_rounded, size: 24, color: Color(0xFFFFB74D)),
          if (dot != null)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF26231F), width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
