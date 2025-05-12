// example/lib/main.dart

import 'package:flutter/material.dart';
import 'package:event_cascade/event_cascade.dart';

/// Two sample event classes.
class NotificationEvent {
  final String message;

  NotificationEvent(this.message);
}

class CounterEvent {
  final int count;

  CounterEvent(this.count);
}

/// A global key so we can grab the NavigatorState & its Overlay.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const DemoApp());

  // After first frame, insert our DispatchControls into the Navigator's overlay:
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay != null) {
      overlay.insert(OverlayEntry(builder: (_) => const DispatchOverlay()));
    }
  });
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [CascadeNavigationTracker()],
      home: const RootScreen(),
    );
  }
}

/// This widget is inserted into the Navigator's overlay, so it's under
/// a Navigator and DropdownButton will work.
class DispatchOverlay extends StatelessWidget {
  const DispatchOverlay({super.key});

  @override
  Widget build(BuildContext c) {
    return Positioned(top: 100, right: 16, child: const DispatchControls());
  }
}

/// UI to configure & fire events.
class DispatchControls extends StatefulWidget {
  const DispatchControls({super.key});

  @override
  _DispatchControlsState createState() => _DispatchControlsState();
}

class _DispatchControlsState extends State<DispatchControls> {
  String _selected = 'Notification';
  final TextEditingController _textCtrl = TextEditingController();
  int _counter = 0;

  @override
  Widget build(BuildContext c) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _selected,
              items: const [
                DropdownMenuItem(
                  value: 'Notification',
                  child: Text('Notification'),
                ),
                DropdownMenuItem(value: 'Counter', child: Text('Counter')),
              ],
              onChanged: (v) => setState(() => _selected = v!),
            ),
            const SizedBox(width: 12),
            if (_selected == 'Notification')
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    isDense: true,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.plus_one),
                tooltip: 'Increment',
                onPressed: () => setState(() => _counter++),
              ),
            const SizedBox(width: 12),
            ElevatedButton(
              child: const Text('Dispatch'),
              onPressed: () {
                if (_selected == 'Notification') {
                  PageCascadeNotifier.dispatch(
                    NotificationEvent(
                      _textCtrl.text.trim().isEmpty
                          ? 'Hello @ ${DateTime.now()}'
                          : _textCtrl.text.trim(),
                    ),
                  );
                } else {
                  PageCascadeNotifier.dispatch(CounterEvent(_counter));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurable Demo')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Push A→B→C→D'),
          onPressed: () {
            for (final page in const [PageA(), PageB(), PageC(), PageD()]) {
              Navigator.push(c, MaterialPageRoute(builder: (_) => page));
            }
          },
        ),
      ),
    );
  }
}

class PageA extends StatelessWidget {
  const PageA({super.key});

  @override
  Widget build(BuildContext c) {
    return PageCascadeNotifier(
      handlers: [
        CascadeEventHandlerImpl<NotificationEvent>((e) {
          debugPrint('[A] saw notification: ${e.message}');
          return false;
        }),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Page A')),
        body: const Center(child: Text('Listens to NotificationEvent')),
      ),
    );
  }
}

class PageB extends StatelessWidget {
  const PageB({super.key});

  @override
  Widget build(BuildContext c) {
    return PageCascadeNotifier(
      handlers: [
        CascadeEventHandlerImpl<NotificationEvent>((e) {
          debugPrint('[B] saw notification: ${e.message}');
          return false;
        }),
        CascadeEventHandlerImpl<CounterEvent>((e) {
          debugPrint('[B] saw counter: ${e.count}');
          return e.count % 2 == 0; // consume if even
        }),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Page B')),
        body: const Center(child: Text('Consumes CounterEvent if even')),
      ),
    );
  }
}

class PageC extends StatelessWidget {
  const PageC({super.key});

  @override
  Widget build(BuildContext c) {
    return PageCascadeNotifier(
      handlers: [
        CascadeEventHandlerImpl<CounterEvent>((e) {
          debugPrint('[C] saw counter: ${e.count}');
          return false;
        }),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Page C')),
        body: const Center(child: Text('Listens to CounterEvent')),
      ),
    );
  }
}

class PageD extends StatelessWidget {
  const PageD({super.key});

  @override
  Widget build(BuildContext c) {
    return PageCascadeNotifier(
      handlers: [
        CascadeEventHandlerImpl<CounterEvent>((e) {
          debugPrint('[D] saw counter: ${e.count}');
          return false;
        }),
        CascadeEventHandlerImpl<NotificationEvent>((e) {
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(SnackBar(content: Text('[D] handled: ${e.message}')));
          return true;
        }),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Page D')),
        body: const Center(child: Text('Consumes NotificationEvent')),
      ),
    );
  }
}
