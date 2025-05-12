/// A top-down, most-recently-active-first event dispatching framework for Flutter.
///
/// This package provides a hierarchical event dispatching system that propagates
/// events from the most recently active UI components (pages, tabs, etc.) down
/// to older ones. It supports:
///
/// * **Hierarchical dispatch**: events propagate from the most recently visible page down to older ones
/// * **Typed handlers**: strongly-typed event handlers to avoid runtime type errors
/// * **Global dispatch**: call `PageCascadeNotifier.dispatch(event)` from anywhere
/// * **Route & Tab support**: automatically tracks route pushes/pops and tab selection
/// * **No static keys**: uses each wrapper's `BuildContext` as the unique identifier
///
/// ## Basic Usage
///
/// 1. Add the navigation tracker to your MaterialApp:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [CascadeNavigationTracker()],
///   home: MyHomePage(),
/// )
/// ```
///
/// 2. Wrap your pages with PageCascadeNotifier:
///
/// ```dart
/// PageCascadeNotifier(
///   handlers: [
///     CascadeEventHandler<MyEvent>((e) {
///       // Handle the event
///       return true; // Return true to consume the event and stop propagation
///     }),
///   ],
///   child: Scaffold(
///     // Your page content
///   ),
/// )
/// ```
///
/// 3. Dispatch events from anywhere:
///
/// ```dart
/// PageCascadeNotifier.dispatch(MyEvent(...));
/// ```
library event_cascade;

export 'src/cascade_event_registry.dart';
export 'src/page_cascade_notifier.dart';
export 'src/cascade_navigation_tracker.dart';
