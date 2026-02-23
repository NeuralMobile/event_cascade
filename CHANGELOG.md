## 0.1.1

### Bug Fixes
* **Deterministic dispatch ordering** — Replaced `DateTime.now()` timestamps with a monotonic counter, eliminating non-deterministic handler ordering when multiple contexts are registered in the same frame.
* **Subclass event matching** — Handlers registered for a supertype (e.g. `Animal`) now receive subclass events (e.g. `Dog`). Exact type match still takes priority over supertype handlers.
* **Tab activation timing** — `_onTabChanged` now guards with `!indexIsChanging` so context activation occurs when the tab animation settles, not at animation start.
* **Handler list comparison** — `didUpdateWidget` now diffs by handler type instead of identity-comparing list instances, avoiding unnecessary unregister/register cycles on every parent rebuild.
* **Route re-subscription** — `_CascadeContextAware` now tracks the subscribed route to avoid re-subscribing on every `didChangeDependencies` call.
* **Tab controller lifecycle** — Proper detach/reattach of tab controller listeners prevents duplicate listeners accumulating across rebuilds.

### Performance
* **Cached sorted context list** — The MRU-sorted context list is now cached and only invalidated when contexts change, eliminating an O(n log n) sort on every dispatch.
* **Per-context handler map** — Restructured handler storage from `Map<Type, Map<Context, handler>>` to `Map<Context, Map<Type, handler>>` for O(1) context cleanup on unregister.
* **Lazy stale-context pruning** — `_pruneStaleContexts` now short-circuits immediately when no stale contexts exist.

### Improvements
* **`CascadeNavigationTracker.instance`** — Added a public static `instance` getter for clearer singleton access.
* **`CascadeEventRegistry.resetForTesting()`** — New `@visibleForTesting` method for reliable test isolation.
* **`FutureOr<bool>` handler signature** — `CascadeEventHandler` now accepts both sync and async callbacks without requiring the `.sync` constructor.

## 0.1.0

* Initial release of event_cascade
* Features:
  * Hierarchical event dispatching from most recently active pages to older ones
  * Strongly-typed event handlers
  * Support for Navigator routes and TabController
  * Automatic context activation based on navigation events
  * Global event dispatching from anywhere in the app
