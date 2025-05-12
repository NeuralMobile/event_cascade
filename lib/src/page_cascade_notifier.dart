import 'package:flutter/material.dart';
import 'cascade_event_registry.dart';
import 'cascade_navigation_tracker.dart';

/// A concrete implementation of [EventHandlerBase] for handling typed events.
///
/// This class wraps a function that processes events of type [T] and implements
/// the [EventHandlerBase] interface for registration with the event registry.
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
  final Future<bool> Function(T) _fn;

  /// Creates a new event handler for events of type [T].
  ///
  /// [_fn] - A function that takes an event of type [T] and returns a Future\<bool\>
  /// indicating whether the event should be consumed (true) or allowed to
  /// propagate to other handlers (false).
  CascadeEventHandler(this._fn);

  /// Creates a new event handler for events of type [T] with a synchronous handler function.
  ///
  /// [fn] - A function that takes an event of type [T] and returns a boolean
  /// indicating whether the event should be consumed (true) or allowed to
  /// propagate to other handlers (false).
  CascadeEventHandler.sync(bool Function(T) fn) : _fn = ((T e) async => fn(e));

  @override
  Type get type => T;

  @override
  Future<bool> handle(dynamic event) => _fn(event as T);
}

/// Mixin to track route lifecycle events and manage context registration.
///
/// This mixin handles the registration and activation of contexts based on
/// route navigation events (push, pop, etc.) and ensures proper cleanup
/// when the widget is disposed.
mixin _CascadeContextAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  @override
  void initState() {
    super.initState();
    // Register this context with the event registry
    CascadeEventRegistry.registerContext(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events if this widget is in a route
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      CascadeNavigationTracker().subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Clean up subscriptions and registrations
    CascadeNavigationTracker().unsubscribe(this);
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
  void didPushNext() {
    // No action needed when a new route is pushed on top
  }

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
    with _CascadeContextAware, RouteAware {
  TabController? _tc;

  @override
  void initState() {
    super.initState();
    // Register all handlers provided in the constructor
    for (final h in widget.handlers) {
      CascadeEventRegistry.registerHandlerBase(context, h);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up tab controller listener if provided
    _tc = widget.tabController;
    if (_tc != null && widget.tabIndex != null) {
      _tc!.addListener(_onTabChanged);
      // If this tab is already selected, mark it active
      if (_tc!.index == widget.tabIndex) {
        CascadeEventRegistry.activateContext(context);
      }
    }
  }

  /// Called when the tab selection changes.
  ///
  /// If this widget's tab becomes selected, its context is activated.
  void _onTabChanged() {
    if (_tc!.index == widget.tabIndex) {
      CascadeEventRegistry.activateContext(context);
    }
  }

  @override
  void dispose() {
    // Unregister all handlers
    for (final h in widget.handlers) {
      CascadeEventRegistry.unregisterHandlerBase(context, h);
    }
    // Remove tab controller listener
    _tc?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
