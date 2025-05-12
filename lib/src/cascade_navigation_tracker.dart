import 'package:flutter/material.dart';

/// A singleton RouteObserver you can import anywhere.
class CascadeNavigationTracker extends RouteObserver<PageRoute<dynamic>> {
  CascadeNavigationTracker._internal();

  static final CascadeNavigationTracker _instance =
      CascadeNavigationTracker._internal();

  factory CascadeNavigationTracker() {
    return _instance;
  }
}
