import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:event_cascade/event_cascade.dart';

class TestEvent {
  final int value;

  TestEvent(this.value);
}

void main() {
  testWidgets('PageCascadeNotifier: only top-most handler is invoked', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [CascadeNavigationTracker()],
        home: Column(
          children: [
            // A bottom notifier that logs but doesn't consume
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) async {
                  calls.add('A');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            // A middle notifier that logs but doesn't consume
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) async {
                  calls.add('B');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            // A top notifier that logs and consumes
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<TestEvent>((e) async {
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

    // Only 'C' should be called
    PageCascadeNotifier.dispatch(TestEvent(42));
    expectLater(calls, ['C']);
  });
}
