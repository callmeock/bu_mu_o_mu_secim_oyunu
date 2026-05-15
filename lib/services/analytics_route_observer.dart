import 'package:flutter/material.dart';
import '../analytics/analytics_constants.dart';
import 'analytics_helper.dart';

class _ScreenRecord {
  _ScreenRecord(this.name, this.enteredAt);
  final String name;
  final DateTime enteredAt;
}

/// [MaterialPageRoute] için [RouteSettings.name] zorunlu; yoksa göz ardı edilir.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver._();
  static final AnalyticsRouteObserver instance = AnalyticsRouteObserver._();

  final List<_ScreenRecord> _stack = <_ScreenRecord>[];

  String? _nameOf(Route<dynamic>? route) {
    final n = route?.settings.name;
    if (n == null || n.isEmpty) return null;
    return n;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = _nameOf(route);
    if (name == null) return;
    _stack.add(_ScreenRecord(name, DateTime.now()));
    AnalyticsNavigationState.setScreen(name);
    final src = _nameOf(previousRoute);
    AnalyticsHelper.screenView(
      screenName: name,
      source: src ?? AnalyticsNavigationState.lastTabScreen,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = _nameOf(route);
    if (name == null) return;

    _ScreenRecord? rec;
    if (_stack.isNotEmpty && _stack.last.name == name) {
      rec = _stack.removeLast();
    } else {
      final i = _stack.lastIndexWhere((r) => r.name == name);
      if (i >= 0) rec = _stack.removeAt(i);
    }
    if (rec != null) {
      final ms = DateTime.now().difference(rec.enteredAt).inMilliseconds;
      AnalyticsHelper.screenExit(screenName: name, durationMs: ms);
    }

    final prevName = _nameOf(previousRoute);
    if (prevName != null) {
      AnalyticsNavigationState.setScreen(prevName);
    } else {
      AnalyticsNavigationState.setScreen(AnalyticsNavigationState.lastTabScreen);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final oldName = _nameOf(oldRoute);
    final newName = _nameOf(newRoute);
    if (oldName != null && _stack.isNotEmpty && _stack.last.name == oldName) {
      final old = _stack.removeLast();
      final ms = DateTime.now().difference(old.enteredAt).inMilliseconds;
      AnalyticsHelper.screenExit(screenName: oldName, durationMs: ms);
    }
    if (newName != null) {
      _stack.add(_ScreenRecord(newName, DateTime.now()));
      AnalyticsNavigationState.setScreen(newName);
      AnalyticsHelper.screenView(
        screenName: newName,
        source: oldName,
      );
    }
  }
}
