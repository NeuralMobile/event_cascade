// lib/src/page_cascade_notifier.dart

import 'package:flutter/material.dart';
import 'cascade_event_registry.dart';
import 'cascade_navigation_tracker.dart';

/// A handler you pass into the constructor:
class CascadeEventHandlerImpl<T> extends CascadeEventHandler {
  final bool Function(T) _fn;

  CascadeEventHandlerImpl(this._fn);

  @override
  Type get type => T;

  @override
  bool handle(dynamic event) => _fn(event as T);
}

/// Mixin to track route pushes/pops and keep contexts registered.
mixin _CascadeContextAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  @override
  void initState() {
    super.initState();
    CascadeEventRegistry.registerContext(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      CascadeNavigationTracker().subscribe(this, route);
    }
  }

  @override
  void dispose() {
    CascadeNavigationTracker().unsubscribe(this);
    CascadeEventRegistry.unregisterContext(context);
    super.dispose();
  }

  @override
  void didPush() => CascadeEventRegistry.activateContext(context);

  @override
  void didPopNext() => CascadeEventRegistry.activateContext(context);

  @override
  void didPushNext() {}

  @override
  void didPop() => CascadeEventRegistry.unregisterContext(context);
}

/// Wrap any page (route or tab) to enable top-down event dispatch.
/// You can now pass your handlers into the constructor.
class PageCascadeNotifier extends StatefulWidget {
  /// If in a TabBarView, supply that controller + this page’s index:
  final TabController? tabController;
  final int? tabIndex;

  /// Typed handlers to register when this widget mounts.
  final List<CascadeEventHandlerImpl<dynamic>> handlers;

  /// Your actual page subtree.
  final Widget child;

  const PageCascadeNotifier({
    Key? key,
    this.tabController,
    this.tabIndex,
    this.handlers = const [],
    required this.child,
  }) : super(key: key);

  @override
  _PageCascadeNotifierState createState() => _PageCascadeNotifierState();

  /// **Static** method on the **class**—call like:
  /// `PageCascadeNotifier.dispatch(MyEvent(...));`
  static void dispatch(dynamic event) {
    CascadeEventRegistry.dispatch(event);
  }
}

class _PageCascadeNotifierState extends State<PageCascadeNotifier>
    with _CascadeContextAware, RouteAware {
  TabController? _tc;

  @override
  void initState() {
    super.initState();
    // register all handlers you passed into the constructor
    for (final h in widget.handlers) {
      CascadeEventRegistry.registerHandlerBase(context, h);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tc = widget.tabController;
    if (_tc != null && widget.tabIndex != null) {
      _tc!.addListener(_onTabChanged);
      // if this tab is already selected, mark it active
      if (_tc!.index == widget.tabIndex) {
        CascadeEventRegistry.activateContext(context);
      }
    }
  }

  void _onTabChanged() {
    if (_tc!.index == widget.tabIndex) {
      CascadeEventRegistry.activateContext(context);
    }
  }

  @override
  void dispose() {
    // unregister your handlers
    for (final h in widget.handlers) {
      CascadeEventRegistry.unregisterHandlerBase(context, h);
    }
    _tc?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
