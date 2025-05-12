import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:event_cascade/src/cascade_event_registry.dart';

class XEvent {
  final String payload;

  XEvent(this.payload);
}

void main() {
  testWidgets(
    'CascadeEventRegistry.dispatch calls handlers in MRU order and stops when consumed',
    (tester) async {
      final calls = <String>[];

      // Build two PageCascadeNotifier wrappers to get distinct contexts
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [],
          home: Column(
            children: [
              // First context
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) async {
                    calls.add('first');
                    return false; // do not consume
                  });
                  return const SizedBox();
                },
              ),
              // Second context (registered later → more recent)
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) async {
                    calls.add('second');
                    return true; // consume
                  });
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      // Dispatch; second should fire first and consume
      CascadeEventRegistry.dispatch(XEvent('hello'));
      expectLater(calls, ['second']);
    },
  );
}
