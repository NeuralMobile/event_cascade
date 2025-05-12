import 'package:flutter/material.dart';

/// Base signature for all wrapped handlers.
abstract class CascadeEventHandler {
  Type get type;

  bool handle(dynamic event);
}

class CascadeEventRegistry {
  static final Map<BuildContext, DateTime> _contextTimestamps = {};
  static final Map<Type, Map<BuildContext, bool Function(dynamic)>> _handlers =
      {};

  static void registerContext(BuildContext ctx) {
    _contextTimestamps[ctx] = DateTime.now();
  }

  static void activateContext(BuildContext ctx) {
    _contextTimestamps[ctx] = DateTime.now();
  }

  static void unregisterContext(BuildContext ctx) {
    _contextTimestamps.remove(ctx);
    for (final m in _handlers.values) {
      m.remove(ctx);
    }
  }

  /// New: register a wrapped handler for its `type`.
  static void registerHandlerBase(BuildContext ctx, CascadeEventHandler h) {
    final map = _handlers.putIfAbsent(h.type, () => {});
    map[ctx] = h.handle;
  }

  /// New: unregister that wrapped handler.
  static void unregisterHandlerBase(BuildContext ctx, CascadeEventHandler h) {
    final map = _handlers[h.type];
    if (map != null) {
      map.remove(ctx);
      if (map.isEmpty) _handlers.remove(h.type);
    }
  }

  static void registerHandler<T>(BuildContext ctx, bool Function(T) handler) {
    final map = _handlers.putIfAbsent(T, () => {});
    map[ctx] = (dynamic e) => handler(e as T);
  }

  static void unregisterHandler<T>(BuildContext ctx) {
    final map = _handlers[T];
    if (map != null) {
      map.remove(ctx);
      if (map.isEmpty) _handlers.remove(T);
    }
  }

  static void dispatch(dynamic event) {
    final active =
        _contextTimestamps.entries.where((e) => e.key.mounted).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final map = _handlers[event.runtimeType];
    if (map == null) return;
    for (final e in active) {
      final h = map[e.key];
      if (h != null && h(event)) break;
    }
  }
}
