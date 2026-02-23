import 'dart:async';

import 'package:flutter/material.dart';
import 'cascade_event_registry.dart';
import 'cascade_navigation_tracker.dart';

/// A concrete implementation of [EventHandlerBase] for handling typed events.
///
/// This class wraps a function that processes events of type [T] and implements
/// the [EventHandlerBase] interface for registration with the event registry.
///
/// Supports subclass matching: a handler for type `Animal` will also
/// receive events of type `Dog extends Animal`.
///
/// Example:
/// ```dart
/// CascadeEventHandler<UserLoggedInEvent>((event) {
///   print('User logged in: ${event.username}');
///   return true; // consume the event
/// })
/// ```
class CascadeEventHandler<T> extends EventHandlerBase {
  /// The function that will handle events of type [T].
  final FutureOr<bool> Function(T) _fn;

  /// Creates a new event handler for events of type [T].
  ///
  /// [_fn] - A function that takes an event of type [T] and returns a
  /// `bool` or `Future<bool>` indicating whether the event should be
  /// consumed (true) or allowed to propagate (false).
  CascadeEventHandler(this._fn);

  /// Creates a new event handler for events of type [T] with a synchronous handler function.
  ///
  /// [fn] - A function that takes an event of type [T] and returns a boolean
  /// indicating whether the event should be consumed (true) or allowed to
  /// propagate to other handlers (false).
  CascadeEventHandler.sync(bool Function(T) fn) : _fn = fn;

  @override
  Type get type => T;

  @override
  bool canHandle(dynamic event) => event is T;

  @override
  Future<bool> handle(dynamic event) async => _fn(event as T);
}

/// Mixin to track route lifecycle events and manage context registration.
///
/// This mixin handles the registration and activation of contexts based on
/// route navigation events (push, pop, etc.) and ensures proper cleanup
/// when the widget is disposed.
mixin _CascadeContextAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    CascadeEventRegistry.registerContext(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        CascadeNavigationTracker.instance.unsubscribe(this);
      }
      _subscribedRoute = route;
      CascadeNavigationTracker.instance.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    CascadeNavigationTracker.instance.unsubscribe(this);
    CascadeEventRegistry.unregisterContext(context);
    super.dispose();
  }

  /// Called when this route has been pushed onto the navigator.
  @override
  void didPush() => CascadeEventRegistry.activateContext(context);

  /// Called when the route above this route has been popped off the navigator.
  @override
  void didPopNext() => CascadeEventRegistry.activateContext(context);

  /// Called when a route has been pushed onto the navigator above this route.
  @override
  void didPushNext() {}

  /// Called when this route has been popped off the navigator.
  @override
  void didPop() => CascadeEventRegistry.unregisterContext(context);
}

/// A widget that enables event handling for a page or tab in your application.
///
/// This widget should wrap any page (route or tab) that needs to receive events
/// from the cascade event system. It manages the registration of event handlers
/// and context activation based on navigation and tab selection.
///
/// Example:
/// ```dart
/// PageCascadeNotifier(
///   handlers: [
///     CascadeEventHandler<NotificationEvent>((e) {
///       showDialog(context: context, builder: (_) => AlertDialog(
///         title: Text('Notification'),
///         content: Text(e.message),
///       ));
///       return true; // consume the event
///     }),
///   ],
///   child: Scaffold(
///     appBar: AppBar(title: Text('My Page')),
///     body: Center(child: Text('Content')),
///   ),
/// )
/// ```
class PageCascadeNotifier extends StatefulWidget {
  /// The tab controller to listen to for tab changes.
  ///
  /// If this widget is inside a TabBarView, provide the TabController here
  /// along with the [tabIndex] to enable automatic context activation when
  /// the tab is selected.
  final TabController? tabController;

  /// The index of this widget in the TabBarView.
  ///
  /// Must be provided if [tabController] is provided.
  final int? tabIndex;

  /// The event handlers to register for this page.
  ///
  /// These handlers will be registered when the widget is created and
  /// unregistered when it is disposed.
  final List<CascadeEventHandler<dynamic>> handlers;

  /// The widget subtree to display.
  final Widget child;

  /// Creates a new PageCascadeNotifier.
  ///
  /// The [child] parameter is required and represents the content of the page.
  /// The [handlers] parameter is optional and defaults to an empty list.
  /// If this widget is inside a TabBarView, provide both [tabController] and [tabIndex].
  const PageCascadeNotifier({
    super.key,
    this.tabController,
    this.tabIndex,
    this.handlers = const [],
    required this.child,
  });

  @override
  PageCascadeNotifierState createState() => PageCascadeNotifierState();

  /// Dispatches an event to all registered handlers.
  ///
  /// Events are dispatched to handlers in order of most recently active context first.
  /// If a handler returns true (consumes the event), propagation stops.
  ///
  /// Example:
  /// ```dart
  /// await PageCascadeNotifier.dispatch(NotificationEvent('Hello, world!'));
  /// ```
  ///
  /// [event] - The event to dispatch.
  static Future<void> dispatch(dynamic event) async {
    await CascadeEventRegistry.dispatch(event);
  }
}

/// The state for [PageCascadeNotifier].
///
/// This class manages the lifecycle of event handlers and tab selection tracking.
class PageCascadeNotifierState extends State<PageCascadeNotifier>
    with _CascadeContextAware {
  TabController? _tc;

  @override
  void initState() {
    super.initState();
    _registerHandlers(widget.handlers);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachTabController(widget.tabController);
  }

  @override
  void didUpdateWidget(PageCascadeNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Unregister handlers for types no longer present
    final newTypes = {for (final h in widget.handlers) h.type};
    for (final h in oldWidget.handlers) {
      if (!newTypes.contains(h.type)) {
        CascadeEventRegistry.unregisterHandlerBase(context, h);
      }
    }
    // Re-register all current handlers (overwrites existing for same type)
    _registerHandlers(widget.handlers);

    if (oldWidget.tabController != widget.tabController ||
        oldWidget.tabIndex != widget.tabIndex) {
      _detachTabController();
      _attachTabController(widget.tabController);
    }
  }

  void _registerHandlers(List<CascadeEventHandler<dynamic>> handlers) {
    for (final h in handlers) {
      CascadeEventRegistry.registerHandlerBase(context, h);
    }
  }

  void _unregisterHandlers(List<CascadeEventHandler<dynamic>> handlers) {
    for (final h in handlers) {
      CascadeEventRegistry.unregisterHandlerBase(context, h);
    }
  }

  void _attachTabController(TabController? tc) {
    if (tc == _tc) return;
    _detachTabController();
    _tc = tc;
    if (_tc != null && widget.tabIndex != null) {
      _tc!.addListener(_onTabChanged);
      if (_tc!.index == widget.tabIndex) {
        CascadeEventRegistry.activateContext(context);
      }
    }
  }

  void _detachTabController() {
    _tc?.removeListener(_onTabChanged);
    _tc = null;
  }

  /// Called when the tab selection changes.
  ///
  /// Only activates the context when the animation has settled
  /// and this widget's tab is selected.
  void _onTabChanged() {
    if (!_tc!.indexIsChanging && _tc!.index == widget.tabIndex) {
      CascadeEventRegistry.activateContext(context);
    }
  }

  @override
  void dispose() {
    _unregisterHandlers(widget.handlers);
    _detachTabController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
