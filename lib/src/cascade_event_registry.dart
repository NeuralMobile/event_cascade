import 'dart:async';

import 'package:flutter/material.dart';

/// Base signature for all event handlers.
///
/// This abstract class defines the interface for event handlers that can be
/// registered with the [CascadeEventRegistry]. Implementations must provide
/// the event [type] they handle, a [canHandle] check, and a [handle] method
/// to process events.
abstract class EventHandlerBase {
  /// The type of event this handler processes.
  Type get type;

  /// Returns `true` if this handler can process [event].
  ///
  /// Used for subclass matching: a handler registered for a parent type
  /// will return true for subclass instances.
  bool canHandle(dynamic event);

  /// Process an event and return true if the event should be consumed
  /// (preventing further propagation to other handlers).
  ///
  /// [event] - The event to handle, which will be cast to the appropriate type.
  ///
  /// Returns a Future that completes with true if the event is consumed,
  /// false to allow it to continue propagating.
  Future<bool> handle(dynamic event);
}

/// Internal handler wrapping a typed callback for the convenience
/// [CascadeEventRegistry.registerHandler] and
/// [CascadeEventRegistry.registerSyncHandler] methods.
class _InternalHandler<T> extends EventHandlerBase {
  final FutureOr<bool> Function(T) _fn;

  _InternalHandler(this._fn);

  @override
  Type get type => T;

  @override
  bool canHandle(dynamic event) => event is T;

  @override
  Future<bool> handle(dynamic event) async => _fn(event as T);
}

/// Central registry for event handlers and context tracking.
///
/// This class manages the registration of contexts and event handlers, and
/// provides the dispatch mechanism for sending events to the appropriate handlers.
/// It maintains a monotonic counter for each context to determine the most
/// recently active contexts for event propagation order.
class CascadeEventRegistry {
  /// Maps BuildContext to its activation order (higher = more recent).
  static final Map<BuildContext, int> _contextOrder = {};
  static int _counter = 0;

  /// Maps BuildContext to its registered handlers, keyed by event type.
  static final Map<BuildContext, Map<Type, EventHandlerBase>> _handlers = {};

  /// Cached sorted context list, invalidated on context changes.
  static List<BuildContext>? _sortedCache;

  /// Registers a BuildContext with the registry.
  ///
  /// This should be called when a widget that can handle events is first created.
  ///
  /// [ctx] - The BuildContext to register.
  static void registerContext(BuildContext ctx) {
    _contextOrder[ctx] = ++_counter;
    _sortedCache = null;
  }

  /// Marks a context as active by updating its order.
  ///
  /// This should be called when a widget becomes visible or active, such as
  /// when a route is pushed or a tab is selected.
  ///
  /// [ctx] - The BuildContext to activate.
  static void activateContext(BuildContext ctx) {
    _contextOrder[ctx] = ++_counter;
    _sortedCache = null;
  }

  /// Unregisters a context and removes all its handlers.
  ///
  /// This should be called when a widget is disposed to clean up resources.
  ///
  /// [ctx] - The BuildContext to unregister.
  static void unregisterContext(BuildContext ctx) {
    _contextOrder.remove(ctx);
    _handlers.remove(ctx);
    _sortedCache = null;
  }

  /// Registers a wrapped handler for its type.
  ///
  /// This method is used to register a [EventHandlerBase] implementation
  /// with the registry.
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [h] - The handler to register.
  static void registerHandlerBase(BuildContext ctx, EventHandlerBase h) {
    final map = _handlers.putIfAbsent(ctx, () => {});
    map[h.type] = h;
  }

  /// Unregisters a wrapped handler.
  ///
  /// This method removes a previously registered [EventHandlerBase].
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [h] - The handler to unregister.
  static void unregisterHandlerBase(BuildContext ctx, EventHandlerBase h) {
    final map = _handlers[ctx];
    if (map != null) {
      final existing = map[h.type];
      if (identical(existing, h)) {
        map.remove(h.type);
      }
      if (map.isEmpty) _handlers.remove(ctx);
    }
  }

  /// Registers a typed event handler function.
  ///
  /// This method allows registering a function that handles events of type [T].
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [handler] - The function that will handle events of type [T].
  static void registerHandler<T>(
      BuildContext ctx, FutureOr<bool> Function(T) handler) {
    registerHandlerBase(ctx, _InternalHandler<T>(handler));
  }

  /// Registers a synchronous typed event handler function.
  ///
  /// This is a convenience method that wraps a synchronous handler.
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [handler] - The synchronous function that will handle events of type [T].
  static void registerSyncHandler<T>(
      BuildContext ctx, bool Function(T) handler) {
    registerHandlerBase(ctx, _InternalHandler<T>(handler));
  }

  /// Unregisters a typed event handler.
  ///
  /// This method removes a previously registered handler for events of type [T].
  ///
  /// [ctx] - The BuildContext associated with the handler.
  static void unregisterHandler<T>(BuildContext ctx) {
    final map = _handlers[ctx];
    if (map != null) {
      map.remove(T);
      if (map.isEmpty) _handlers.remove(ctx);
    }
  }

  /// Dispatches an event to registered handlers.
  ///
  /// Events are dispatched to handlers in order of most recently active context
  /// first. If a handler returns true (consumes the event), propagation stops.
  ///
  /// Supports subclass matching: if no exact-type handler is found for a
  /// context, a supertype handler that can handle the event will be tried.
  ///
  /// [event] - The event to dispatch.
  static Future<void> dispatch(dynamic event) async {
    _pruneStaleContexts();
    final sorted = _sortedCache ??= _buildSortedList();

    for (final ctx in sorted) {
      final ctxHandlers = _handlers[ctx];
      if (ctxHandlers == null) continue;

      // Fast path: exact type match
      final exact = ctxHandlers[event.runtimeType];
      if (exact != null) {
        if (await exact.handle(event)) return;
        continue;
      }

      // Slow path: supertype handler match
      for (final h in ctxHandlers.values.toList().reversed) {
        if (h.canHandle(event)) {
          if (await h.handle(event)) return;
        }
      }
    }
  }

  static List<BuildContext> _buildSortedList() {
    final entries = _contextOrder.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// Removes entries for contexts that are no longer mounted.
  static void _pruneStaleContexts() {
    final stale = _contextOrder.keys.where((ctx) => !ctx.mounted).toList();
    if (stale.isEmpty) return;
    for (final ctx in stale) {
      _contextOrder.remove(ctx);
      _handlers.remove(ctx);
    }
    _sortedCache = null;
  }

  /// Clears all internal state. Intended for test isolation only.
  @visibleForTesting
  static void resetForTesting() {
    _contextOrder.clear();
    _handlers.clear();
    _counter = 0;
    _sortedCache = null;
  }
}
