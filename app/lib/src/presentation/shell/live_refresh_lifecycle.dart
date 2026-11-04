import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/live_refresh_providers.dart';

/// Relit les données affichées quand l'application revient au premier plan (poste sorti de veille, mobile rouvert) : le canal temps
/// réel a pu être coupé par le système sans qu'aucun événement n'arrive.
class LiveRefreshLifecycle extends ConsumerStatefulWidget {
  const LiveRefreshLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveRefreshLifecycle> createState() => _LiveRefreshLifecycleState();
}

class _LiveRefreshLifecycleState extends ConsumerState<LiveRefreshLifecycle> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(liveRefreshProvider).refreshAll();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
