import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:event_cascade/event_cascade.dart';

class XEvent {
  final String payload;

  XEvent(this.payload);
}

class YEvent {
  final int value;

  YEvent(this.value);
}

class XSubEvent extends XEvent {
  final int extra;

  XSubEvent(super.payload, this.extra);
}

void main() {
  tearDown(() {
    CascadeEventRegistry.resetForTesting();
  });

  testWidgets(
    'dispatch calls handlers in MRU order and stops when consumed',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('first');
                    return false;
                  });
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('second');
                    return true;
                  });
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(XEvent('hello'));
      expect(calls, ['second']);
    },
  );

  testWidgets(
    'dispatch propagates to all handlers when none consume',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('first');
                    return false;
                  });
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('second');
                    return false;
                  });
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(XEvent('hello'));
      expect(calls, ['second', 'first']);
    },
  );

  testWidgets(
    'dispatch ignores handlers for unrelated event types',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              CascadeEventRegistry.registerContext(c);
              CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                calls.add('x');
                return true;
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(YEvent(42));
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'resetForTesting clears all state',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              CascadeEventRegistry.registerContext(c);
              CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                calls.add('handled');
                return true;
              });
              return const SizedBox();
            },
          ),
        ),
      );

      CascadeEventRegistry.resetForTesting();
      await CascadeEventRegistry.dispatch(XEvent('hello'));
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'subclass event matches supertype handler',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              CascadeEventRegistry.registerContext(c);
              CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                calls.add('x:${e.payload}');
                return true;
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(XSubEvent('hello', 42));
      expect(calls, ['x:hello']);
    },
  );

  testWidgets(
    'exact type handler takes priority over supertype handler',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              CascadeEventRegistry.registerContext(c);
              CascadeEventRegistry.registerHandlerBase(
                c,
                CascadeEventHandler<XEvent>((e) {
                  calls.add('super');
                  return true;
                }),
              );
              CascadeEventRegistry.registerHandlerBase(
                c,
                CascadeEventHandler<XSubEvent>((e) {
                  calls.add('exact:${e.extra}');
                  return true;
                }),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(XSubEvent('hello', 99));
      expect(calls, ['exact:99']);
    },
  );

  testWidgets(
    'monotonic ordering is deterministic for same-frame registrations',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('A');
                    return false;
                  });
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('B');
                    return false;
                  });
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (c) {
                  CascadeEventRegistry.registerContext(c);
                  CascadeEventRegistry.registerHandler<XEvent>(c, (e) {
                    calls.add('C');
                    return false;
                  });
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(XEvent('test'));
      expect(calls, ['C', 'B', 'A']);
    },
  );
}
