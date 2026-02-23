import 'dart:async';

import 'package:event_cascade/event_cascade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class LimitBaseEvent {
  final String id;

  LimitBaseEvent(this.id);
}

class LimitChildEvent extends LimitBaseEvent {
  final int code;

  LimitChildEvent(super.id, this.code);
}

class LimitOtherEvent {
  final int value;

  LimitOtherEvent(this.value);
}

/// Exposes [hasListeners] for test assertions.
class _TestableTabController extends TabController {
  _TestableTabController({required super.length, required super.vsync});

  @override
  bool get hasListeners => super.hasListeners;
}

void main() {
  tearDown(() {
    CascadeEventRegistry.resetForTesting();
  });

  group('Registry API and dispatch limits', () {
    testWidgets('registerHandler accepts sync and async callbacks', (
      tester,
    ) async {
      final calls = <String>[];
      late BuildContext tracked;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              tracked = context;
              CascadeEventRegistry.registerContext(context);
              CascadeEventRegistry.registerHandler<LimitBaseEvent>(context, (
                _,
              ) {
                calls.add('base-sync');
                return true;
              });
              CascadeEventRegistry.registerHandler<LimitOtherEvent>(context, (
                _,
              ) async {
                calls.add('other-async');
                return true;
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(LimitBaseEvent('x'));
      await CascadeEventRegistry.dispatch(LimitOtherEvent(1));
      expect(calls, ['base-sync', 'other-async']);

      calls.clear();
      CascadeEventRegistry.unregisterHandler<LimitBaseEvent>(tracked);
      await CascadeEventRegistry.dispatch(LimitBaseEvent('removed'));
      await CascadeEventRegistry.dispatch(LimitOtherEvent(2));
      expect(calls, ['other-async']);
    });

    testWidgets(
        'registerSyncHandler is overwritten by later handler of same type', (
      tester,
    ) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              CascadeEventRegistry.registerContext(context);
              CascadeEventRegistry.registerSyncHandler<LimitBaseEvent>(
                context,
                (_) {
                  calls.add('sync');
                  return true;
                },
              );
              CascadeEventRegistry.registerHandler<LimitBaseEvent>(context, (
                _,
              ) async {
                calls.add('async');
                return true;
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(LimitBaseEvent('x'));
      expect(calls, ['async']);
    });

    testWidgets('awaits newest async handler before moving to older context', (
      tester,
    ) async {
      final calls = <String>[];
      final gate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) {
                      calls.add('older');
                      return false;
                    },
                  );
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) async {
                      calls.add('newer:start');
                      await gate.future;
                      calls.add('newer:end');
                      return false;
                    },
                  );
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      final dispatch = CascadeEventRegistry.dispatch(LimitBaseEvent('x'));
      await tester.pump();
      expect(calls, ['newer:start']);

      gate.complete();
      await dispatch;
      expect(calls, ['newer:start', 'newer:end', 'older']);
    });

    testWidgets('async consumer prevents propagation after await completes', (
      tester,
    ) async {
      final calls = <String>[];
      final gate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) {
                      calls.add('older');
                      return false;
                    },
                  );
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) async {
                      calls.add('newer:start');
                      await gate.future;
                      calls.add('newer:end');
                      return true;
                    },
                  );
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      final dispatch = CascadeEventRegistry.dispatch(LimitBaseEvent('x'));
      await tester.pump();
      expect(calls, ['newer:start']);

      gate.complete();
      await dispatch;
      expect(calls, ['newer:start', 'newer:end']);
    });

    testWidgets('supports nested dispatch from inside another handler', (
      tester,
    ) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) {
                      calls.add('older-base');
                      return false;
                    },
                  );
                  CascadeEventRegistry.registerHandler<LimitOtherEvent>(
                    context,
                    (_) {
                      calls.add('older-other');
                      return false;
                    },
                  );
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) async {
                      calls.add('newer-base:start');
                      await CascadeEventRegistry.dispatch(LimitOtherEvent(99));
                      calls.add('newer-base:end');
                      return false;
                    },
                  );
                  CascadeEventRegistry.registerHandler<LimitOtherEvent>(
                    context,
                    (_) {
                      calls.add('newer-other');
                      return false;
                    },
                  );
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(LimitBaseEvent('outer'));
      expect(
        calls,
        [
          'newer-base:start',
          'newer-other',
          'older-other',
          'newer-base:end',
          'older-base',
        ],
      );
    });

    testWidgets('exact Null handler takes precedence over Object handler', (
      tester,
    ) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              CascadeEventRegistry.registerContext(context);
              CascadeEventRegistry.registerHandler<Object>(context, (_) {
                calls.add('object');
                return true;
              });
              CascadeEventRegistry.registerHandler<Null>(context, (_) {
                calls.add('null');
                return true;
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(null);
      expect(calls, ['null']);
    });

    testWidgets(
      'fallback matching prefers the most recently registered matching supertype',
      (tester) async {
        final calls = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                CascadeEventRegistry.registerContext(context);
                CascadeEventRegistry.registerHandler<Object>(context, (_) {
                  calls.add('object');
                  return false;
                });
                CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                  context,
                  (_) {
                    calls.add('base');
                    return true;
                  },
                );
                return const SizedBox();
              },
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(LimitChildEvent('x', 7));
        expect(calls, ['base']);
      },
    );

    testWidgets('high-frequency dispatch still short-circuits at top context', (
      tester,
    ) async {
      const contextCount = 120;
      const dispatchCount = 200;
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            children: List.generate(contextCount, (index) {
              return Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) {
                      callCount++;
                      return index == contextCount - 1;
                    },
                  );
                  return const SizedBox(height: 1);
                },
              );
            }),
          ),
        ),
      );

      for (var i = 0; i < dispatchCount; i++) {
        await CascadeEventRegistry.dispatch(LimitBaseEvent('event-$i'));
      }

      expect(callCount, dispatchCount);
    });
  });

  group(
    'Strict semantics',
    () {
      testWidgets(
        'dispatch continues to the next matching supertype in the same context when earlier one returns false',
        (tester) async {
          final calls = <String>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<Object>(context, (_) {
                    calls.add('object');
                    return true;
                  });
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) {
                      calls.add('base');
                      return false;
                    },
                  );
                  return const SizedBox();
                },
              ),
            ),
          );

          await CascadeEventRegistry.dispatch(LimitChildEvent('x', 10));
          expect(calls, ['base', 'object']);
        },
      );

      testWidgets(
        'dispatch should prefer the most recently registered matching supertype when multiple match',
        (tester) async {
          final calls = <String>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandler<Object>(context, (_) {
                    calls.add('object');
                    return true;
                  });
                  CascadeEventRegistry.registerHandler<LimitBaseEvent>(
                    context,
                    (_) {
                      calls.add('base');
                      return true;
                    },
                  );
                  return const SizedBox();
                },
              ),
            ),
          );

          await CascadeEventRegistry.dispatch(LimitChildEvent('x', 11));
          expect(calls, ['base']);
        },
      );

      testWidgets(
        'unregisterHandlerBase should remove only the same handler instance',
        (tester) async {
          final calls = <String>[];
          late BuildContext tracked;
          late CascadeEventHandler<LimitBaseEvent> active;
          late CascadeEventHandler<LimitBaseEvent> differentInstance;

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  tracked = context;
                  CascadeEventRegistry.registerContext(context);
                  active = CascadeEventHandler<LimitBaseEvent>((_) {
                    calls.add('active');
                    return true;
                  });
                  differentInstance = CascadeEventHandler<LimitBaseEvent>((_) {
                    calls.add('different');
                    return true;
                  });
                  CascadeEventRegistry.registerHandlerBase(context, active);
                  return const SizedBox();
                },
              ),
            ),
          );

          CascadeEventRegistry.unregisterHandlerBase(
              tracked, differentInstance);
          await CascadeEventRegistry.dispatch(LimitBaseEvent('x'));
          expect(calls, ['active']);
        },
      );
    },
  );

  group('PageCascadeNotifier controller lifecycle', () {
    testWidgets(
        'swapping tabController detaches old listener and attaches new one', (
      tester,
    ) async {
      final tc1 = _TestableTabController(length: 2, vsync: const TestVSync());
      final tc2 = _TestableTabController(length: 2, vsync: const TestVSync());

      Widget buildWith(TabController? tc) {
        return MaterialApp(
          home: PageCascadeNotifier(
            tabController: tc,
            tabIndex: 0,
            handlers: [
              CascadeEventHandler<LimitBaseEvent>((_) => true),
            ],
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildWith(tc1));
      expect(tc1.hasListeners, isTrue);
      expect(tc2.hasListeners, isFalse);

      await tester.pumpWidget(buildWith(tc2));
      expect(tc1.hasListeners, isFalse);
      expect(tc2.hasListeners, isTrue);

      await tester.pumpWidget(buildWith(null));
      expect(tc2.hasListeners, isFalse);

      tc1.dispose();
      tc2.dispose();
    });

    testWidgets('removing tabController on update detaches listener', (
      tester,
    ) async {
      final tc = _TestableTabController(length: 3, vsync: const TestVSync());

      Widget buildWith(TabController? current) {
        return MaterialApp(
          home: PageCascadeNotifier(
            tabController: current,
            tabIndex: 1,
            handlers: [
              CascadeEventHandler<LimitBaseEvent>((_) => true),
            ],
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildWith(tc));
      expect(tc.hasListeners, isTrue);

      await tester.pumpWidget(buildWith(null));
      expect(tc.hasListeners, isFalse);

      tc.dispose();
    });
  });

  test('CascadeNavigationTracker factory returns singleton instance', () {
    expect(
        identical(
            CascadeNavigationTracker(), CascadeNavigationTracker.instance),
        isTrue);
  });
}
