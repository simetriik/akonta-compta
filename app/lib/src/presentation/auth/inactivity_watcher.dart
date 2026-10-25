import 'dart:async';

import 'package:flutter/material.dart';

/// Déconnecte après une durée d'inactivité (aucune frappe ni clic), paramétrable par cabinet (§10.1).
/// Le minuteur est testable : `InactivityController` est indépendant des widgets.
class InactivityController {
  InactivityController({required this.timeout, required this.onTimeout, this.enabled = true});

  final Duration timeout;
  final VoidCallback onTimeout;
  bool enabled;
  Timer? _timer;

  void reset() {
    _timer?.cancel();
    if (!enabled) return;
    _timer = Timer(timeout, onTimeout);
  }

  void dispose() => _timer?.cancel();
}

class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({super.key, required this.timeout, required this.onTimeout, required this.enabled, required this.child});

  final Duration timeout;
  final VoidCallback onTimeout;
  final bool enabled;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  late InactivityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InactivityController(timeout: widget.timeout, onTimeout: widget.onTimeout, enabled: widget.enabled)..reset();
  }

  @override
  void didUpdateWidget(covariant InactivityWatcher old) {
    super.didUpdateWidget(old);
    if (old.timeout != widget.timeout || old.enabled != widget.enabled) {
      _controller.dispose();
      _controller = InactivityController(timeout: widget.timeout, onTimeout: widget.onTimeout, enabled: widget.enabled)..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _controller.reset(),
      onPointerSignal: (_) => _controller.reset(),
      child: Focus(
        onKeyEvent: (_, _) {
          _controller.reset();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
