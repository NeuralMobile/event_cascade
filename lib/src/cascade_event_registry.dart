import 'package:flutter/material.dart';

/// Base signature for all event handlers.
///
/// This abstract class defines the interface for event handlers that can be
/// registered with the [CascadeEventRegistry]. Implementations must provide
/// the event [type] they handle and a [handle] method to process events.
abstract class EventHandlerBase {
  /// The type of event this handler processes.
  Type get type;

  /// Process an event and return true if the event should be consumed
  /// (preventing further propagation to other handlers).
  ///
  /// [event] - The event to handle, which will be cast to the appropriate type.
  ///
  /// Returns a Future that completes with true if the event is consumed,
  /// false to allow it to continue propagating.
  Future<bool> handle(dynamic event);
}

/// Central registry for event handlers and context tracking.
///
/// This class manages the registration of contexts and event handlers, and
/// provides the dispatch mechanism for sending events to the appropriate handlers.
/// It maintains a timestamp for each context to determine the most recently active
/// contexts for event propagation order.
class CascadeEventRegistry {
  /// Maps BuildContext to its last activation timestamp
  static final Map<BuildContext, DateTime> _contextTimestamps = {};

  /// Maps event Type to a map of BuildContext -> handler function
  static final Map<Type, Map<BuildContext, Future<bool> Function(dynamic)>>
      _handlers = {};

  /// Registers a BuildContext with the registry.
  ///
  /// This should be called when a widget that can handle events is first created.
  /// The context is timestamped with the current time.
  ///
  /// [ctx] - The BuildContext to register.
  static void registerContext(BuildContext ctx) {
    _contextTimestamps[ctx] = DateTime.now();
  }

  /// Marks a context as active by updating its timestamp.
  ///
  /// This should be called when a widget becomes visible or active, such as
  /// when a route is pushed or a tab is selected.
  ///
  /// [ctx] - The BuildContext to activate.
  static void activateContext(BuildContext ctx) {
    _contextTimestamps[ctx] = DateTime.now();
  }

  /// Unregisters a context and removes all its handlers.
  ///
  /// This should be called when a widget is disposed to clean up resources.
  ///
  /// [ctx] - The BuildContext to unregister.
  static void unregisterContext(BuildContext ctx) {
    _contextTimestamps.remove(ctx);
    for (final m in _handlers.values) {
      m.remove(ctx);
    }
  }

  /// Registers a wrapped handler for its type.
  ///
  /// This method is used to register a [EventHandlerBase] implementation
  /// with the registry.
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [h] - The handler to register.
  static void registerHandlerBase(BuildContext ctx, EventHandlerBase h) {
    final map = _handlers.putIfAbsent(h.type, () => {});
    map[ctx] = h.handle;
  }

  /// Unregisters a wrapped handler.
  ///
  /// This method removes a previously registered [EventHandlerBase].
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [h] - The handler to unregister.
  static void unregisterHandlerBase(BuildContext ctx, EventHandlerBase h) {
    final map = _handlers[h.type];
    if (map != null) {
      map.remove(ctx);
      if (map.isEmpty) _handlers.remove(h.type);
    }
  }

  /// Registers a typed event handler function.
  ///
  /// This method allows registering a function that handles events of type [T].
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [handler] - The function that will handle events of type [T].
  static void registerHandler<T>(
      BuildContext ctx, Future<bool> Function(T) handler) {
    final map = _handlers.putIfAbsent(T, () => {});
    map[ctx] = (dynamic e) => handler(e as T);
  }

  /// Registers a synchronous typed event handler function.
  ///
  /// This is a convenience method that wraps a synchronous handler in an async function.
  ///
  /// [ctx] - The BuildContext associated with the handler.
  /// [handler] - The synchronous function that will handle events of type [T].
  static void registerSyncHandler<T>(
      BuildContext ctx, bool Function(T) handler) {
    final map = _handlers.putIfAbsent(T, () => {});
    map[ctx] = (dynamic e) async {
      return handler(e as T);
    };
  }

  /// Unregisters a typed event handler.
  ///
  /// This method removes a previously registered handler for events of type [T].
  ///
  /// [ctx] - The BuildContext associated with the handler.
  static void unregisterHandler<T>(BuildContext ctx) {
    final map = _handlers[T];
    if (map != null) {
      map.remove(ctx);
      if (map.isEmpty) _handlers.remove(T);
    }
  }

  /// Dispatches an event to registered handlers.
  ///
  /// Events are dispatched to handlers in order of most recently active context first.
  /// If a handler returns true (consumes the event), propagation stops.
  ///
  /// [event] - The event to dispatch.
  static Future<void> dispatch(dynamic event) async {
    // Get all mounted contexts sorted by most recent first
    final active = _contextTimestamps.entries
        .where((e) => e.key.mounted)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Find handlers for this event type
    final map = _handlers[event.runtimeType];
    if (map == null) return;

    // Call handlers in order until one consumes the event
    for (final e in active) {
      final h = map[e.key];
      if (h != null) {
        final result = await h(event);
        if (result) break;
      }
    }
  }
}
