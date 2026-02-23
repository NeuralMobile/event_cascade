import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:event_cascade/event_cascade.dart';

class TestEvent {
  final int value;

  TestEvent(this.value);
}

class OtherEvent {
  final String data;

  OtherEvent(this.data);
}

void main() {
  tearDown(() {
    CascadeEventRegistry.resetForTesting();
  });

  testWidgets('only top-most handler is invoked when it consumes', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [CascadeNavigationTracker.instance],
        home: Column(
          children: [
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) {
                  calls.add('A');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) {
                  calls.add('B');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) {
                  calls.add('C');
                  return true;
                }),
              ],
              child: const SizedBox(),
            ),
          ],
        ),
      ),
    );

    await PageCascadeNotifier.dispatch(TestEvent(42));
    expect(calls, ['C']);
  });

  testWidgets('all handlers invoked in MRU order when none consume', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [CascadeNavigationTracker.instance],
        home: Column(
          children: [
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) {
                  calls.add('A');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) {
                  calls.add('B');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
          ],
        ),
      ),
    );

    await PageCascadeNotifier.dispatch(TestEvent(1));
    expect(calls, ['B', 'A']);
  });

  testWidgets('handlers are cleaned up on dispose', (tester) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [CascadeNavigationTracker.instance],
        home: PageCascadeNotifier(
          handlers: [
            CascadeEventHandler<TestEvent>((e) {
              calls.add('handled');
              return true;
            }),
          ],
          child: const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [CascadeNavigationTracker.instance],
        home: const SizedBox(),
      ),
    );

    await PageCascadeNotifier.dispatch(TestEvent(1));
    expect(calls, isEmpty);
  });

  testWidgets(
    'popped route does not receive events before dispose completes',
    (tester) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [CascadeNavigationTracker.instance],
          home: PageCascadeNotifier(
            handlers: [
              CascadeEventHandler<TestEvent>((e) {
                calls.add('home');
                return false;
              }),
            ],
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PageCascadeNotifier(
                        handlers: [
                          CascadeEventHandler<TestEvent>((e) {
                            calls.add('pushed');
                            return true;
                          }),
                        ],
                        child: const Scaffold(),
                      ),
                    ),
                  );
                },
                child: const Text('push'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      calls.clear();
      await PageCascadeNotifier.dispatch(TestEvent(1));
      expect(calls, ['pushed']);

      // Pop the pushed route — the widget is still alive (pop animation)
      // but didPop should immediately stop event delivery.
      Navigator.of(tester.element(find.byType(Scaffold))).pop();
      await tester.pump(); // start pop, didPop fires

      calls.clear();
      await PageCascadeNotifier.dispatch(TestEvent(2));
      expect(calls, ['home'],
          reason: 'popped route must not receive events; '
              'home route should now be the active handler');

      await tester.pumpAndSettle(); // finish animation & dispose
    },
  );

  testWidgets('multiple event types dispatched correctly', (tester) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [CascadeNavigationTracker.instance],
        home: PageCascadeNotifier(
          handlers: [
            CascadeEventHandler<TestEvent>((e) {
              calls.add('test:${e.value}');
              return true;
            }),
            CascadeEventHandler<OtherEvent>((e) {
              calls.add('other:${e.data}');
              return true;
            }),
          ],
          child: const SizedBox(),
        ),
      ),
    );

    await PageCascadeNotifier.dispatch(TestEvent(5));
    await PageCascadeNotifier.dispatch(OtherEvent('hello'));
    expect(calls, ['test:5', 'other:hello']);
  });
}
