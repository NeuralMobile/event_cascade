import 'package:flutter/material.dart';
import 'package:event_cascade/event_cascade.dart';

/// Two sample event classes.
class GreetingEvent {
  final String message;

  GreetingEvent(this.message);
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
    const padding = 16.0;
    final edgeInsets = MediaQuery.of(c).viewPadding;
    return Positioned(
      top: edgeInsets.top + AppBar().preferredSize.height + padding,
      right: padding,
      left: padding,
      child: const DispatchControls(),
    );
  }
}

/// UI to configure & fire events.
class DispatchControls extends StatefulWidget {
  const DispatchControls({super.key});

  @override
  DispatchControlsState createState() => DispatchControlsState();
}

class DispatchControlsState extends State<DispatchControls> {
  String _selected = 'Greeting';
  final TextEditingController _textCtrl = TextEditingController();
  int _counter = 0;

  @override
  Widget build(BuildContext c) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Radio(
                    value: 'Greeting',
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v!),
                  ),
                  Text('Greeting Event'),
                  Radio(
                    value: 'Counter',
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v!),
                  ),
                  Text('Counter Event'),
                ],
              ),
              SizedBox(height: 12),
              if (_selected == 'Greeting')
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _counter--),
                      child: Text(
                        '➖',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '$_counter',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _counter++),
                      child: Text(
                        '➕',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 12),
              ElevatedButton(
                child: const Text('Dispatch'),
                onPressed: () async {
                  if (_selected == 'Greeting') {
                    await PageCascadeNotifier.dispatch(
                      GreetingEvent(
                        _textCtrl.text.trim().isEmpty
                            ? 'Hello @ ${DateTime.now()}'
                            : _textCtrl.text.trim(),
                      ),
                    );
                  } else {
                    await PageCascadeNotifier.dispatch(CounterEvent(_counter));
                  }
                },
              ),
            ],
          ),
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
        CascadeEventHandler<GreetingEvent>((e) {
          debugPrint('[A] saw notification: ${e.message}');
          return Future.value(false);
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
        CascadeEventHandler<GreetingEvent>((e) {
          debugPrint('[B] saw notification: ${e.message}');
          return Future.value(false);
        }),
        CascadeEventHandler<CounterEvent>((e) {
          debugPrint('[B] saw counter: ${e.count}');
          return Future.value(e.count % 2 == 0); // consume if even
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
        CascadeEventHandler<CounterEvent>((e) {
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(SnackBar(content: Text('[C] handled: ${e.count}')));
          return Future.value(true);
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
        CascadeEventHandler<CounterEvent>((e) {
          debugPrint('[D] saw counter: ${e.count}');
          return Future.value(false);
        }),
        CascadeEventHandler<GreetingEvent>((e) {
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(SnackBar(content: Text('[D] handled: ${e.message}')));
          return Future.value(true);
        }),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('Page D')),
        body: const Center(child: Text('Consumes NotificationEvent')),
      ),
    );
  }
}
