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
                CascadeEventHandlerImpl<TestEvent>((e) {
                  calls.add('A');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            // A middle notifier that logs but doesn't consume
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandlerImpl<TestEvent>((e) {
                  calls.add('B');
                  return false;
                }),
              ],
              child: const SizedBox(),
            ),
            // A top notifier that logs and consumes
            PageCascadeNotifier(
              handlers: [
                CascadeEventHandlerImpl<TestEvent>((e) {
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
    expect(calls, ['C']);
  });
}
