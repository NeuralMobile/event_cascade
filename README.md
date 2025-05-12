# event\_cascade

[![pub version](https://img.shields.io/pub/v/event_cascade)](https://pub.dev/packages/event_cascade)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A **top‑down**, **most‑recently‑active‑first** event dispatch framework for Flutter.
Supports multiple event types, works with Navigator routes, custom `TabController`s, or any context‑based UI (tabs, drawers, etc.).

---

## 🌟 Features

* **Hierarchical dispatch**: events propagate from the most recently visible page down to older ones
* **Typed handlers**: strongly‑typed `CascadeEventHandler<T>` avoids runtime casts
* **Global dispatch**: call `PageCascadeNotifier.dispatch(event)` anywhere
* **Route & Tab support**: automatically tracks route pushes/pops and tab selection
* **No static keys**: uses each wrapper’s `BuildContext` as the unique identifier

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  event_cascade: ^0.1.0
```

Then run:

```bash
flutter pub get
```

---

## 🚀 Quick Start

1. **Import** the package:

   ```dart
   import 'package:event_cascade/event_cascade.dart';
   ```

2. **Wrap** each “page” (route or tab) in a `PageCascadeNotifier`, supplying any handlers:

   ```dart
   class MyPage extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return PageCascadeNotifier(
         handlers: [
           CascadeEventHandler<MyEvent>((e) {
             // handle event e
             return true; // consume to stop propagation
           }),
         ],
         child: Scaffold(
           appBar: AppBar(title: Text('My Page')),
           body: Center(child: Text('Content')),  
         ),
       );
     }
   }
   ```

3. **Dispatch** events from anywhere:

   ```dart
   PageCascadeNotifier.dispatch(MyEvent(...));
   ```

4. **Ensure** you add the singleton `NavigationTracker` to your `MaterialApp`:

   ```dart
   MaterialApp(
     navigatorObservers: [NavigationTracker.instance],
     home: RootScreen(),
   );
   ```

---

## 🛠️ API Reference

### `CascadeEventHandler<T>`

Wraps a typed handler function:

```dart
CascadeEventHandler<NotificationEvent>((e) {
  // process e
  return true;  // consume
});
```

### `PageCascadeNotifier` widget

Tracks context visibility and registers handlers:

* **Constructor**:

    * `tabController` + `tabIndex` (optional) for tabs
    * `handlers`: list of `CascadeEventHandler<dynamic>`
    * `child`: your page subtree

* **Static methods**:

    * `dispatch(dynamic event)`: fire an event

### `NavigationTracker`

A singleton `RouteObserver<PageRoute>` you must add to `navigatorObservers`:

```dart
MaterialApp(
  navigatorObservers: [NavigationTracker.instance],
  // ...
)
```

---

## 🔧 Example

```dart
import 'package:flutter/material.dart';
import 'package:event_cascade/event_cascade.dart';

class PingEvent { final String msg; PingEvent(this.msg); }

void main() => runApp(
  MaterialApp(
    navigatorObservers: [NavigationTracker.instance],
    home: HomeScreen(),
    builder: (ctx, child) => Stack(
      children: [ child!, Positionned(/* global FAB to dispatch */) ],
    ),
  ),
);

class HomeScreen extends StatelessWidget {
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('Home')),
    body: Center(child: ElevatedButton(
      child: Text('Go to Next'),
      onPressed: () => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => NextPage()),
      ),
    )),
  );
}

class NextPage extends StatelessWidget {
  @override Widget build(BuildContext c) {
    return PageCascadeNotifier(
      handlers: [
        CascadeEventHandler<PingEvent>((e) {
          // Show a SnackBar
          ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(content: Text('Received: ${e.msg}')),
          );
          return true; // consume
        }),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text('Next')), body: Center(child: Text('Waiting for event…')),
      ),
    );
  }
}
```

---

## 🧪 Testing

The package includes unit and widget tests under `test/`. To run:

```bash
flutter test
```

---

## 🤝 Contributing

1. Fork the repo: `git clone https://github.com/your_org/event_cascade.git`
2. Create a branch: `git checkout -b feature/my-cool-feature`
3. Commit changes & push
4. Open a Pull Request and describe your change

Please follow the existing style and add tests for new functionality.

---

## 📄 License

MIT © \[Your Name]
