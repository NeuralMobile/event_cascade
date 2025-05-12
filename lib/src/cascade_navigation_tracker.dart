import 'package:flutter/material.dart';

/// A singleton [RouteObserver] that tracks navigation events for the event cascade system.
///
/// This class extends Flutter's [RouteObserver] to track route navigation events
/// (push, pop, etc.) and is implemented as a singleton to ensure a single instance
/// is used throughout the application.
///
/// You must add this observer to your [MaterialApp] or [Navigator] to enable
/// proper route tracking:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [CascadeNavigationTracker()],
///   home: MyHomePage(),
/// )
/// ```
///
/// The [PageCascadeNotifier] widget uses this tracker to subscribe to route events
/// and update context activation timestamps accordingly.
class CascadeNavigationTracker extends RouteObserver<PageRoute<dynamic>> {
  /// Private constructor for singleton pattern
  CascadeNavigationTracker._internal();

  /// The singleton instance
  static final CascadeNavigationTracker _instance =
      CascadeNavigationTracker._internal();

  /// Factory constructor that returns the singleton instance.
  ///
  /// Always use this constructor to get the instance:
  /// ```dart
  /// final tracker = CascadeNavigationTracker();
  /// ```
  factory CascadeNavigationTracker() {
    return _instance;
  }
}
