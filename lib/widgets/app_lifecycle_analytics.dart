import 'package:flutter/widgets.dart';
import '../services/analytics_helper.dart';

/// [app_backgrounded] / [app_foregrounded] için [WidgetsBindingObserver].
class AppLifecycleAnalytics extends StatefulWidget {
  const AppLifecycleAnalytics({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleAnalytics> createState() => _AppLifecycleAnalyticsState();
}

class _AppLifecycleAnalyticsState extends State<AppLifecycleAnalytics>
    with WidgetsBindingObserver {
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
    switch (state) {
      case AppLifecycleState.paused:
        AnalyticsHelper.appBackgrounded();
        break;
      case AppLifecycleState.resumed:
        AnalyticsHelper.appForegrounded();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
