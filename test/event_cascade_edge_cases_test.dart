import 'package:event_cascade/event_cascade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class BaseEvent {
  final String label;

  BaseEvent(this.label);
}

class ChildEvent extends BaseEvent {
  final int code;

  ChildEvent(super.label, this.code);
}

class AnotherEvent {
  final int value;

  AnotherEvent(this.value);
}

void main() {
  tearDown(() {
    CascadeEventRegistry.resetForTesting();
  });

  group('CascadeEventRegistry edge cases', () {
    testWidgets('dispatch with no registrations is a no-op', (tester) async {
      await CascadeEventRegistry.dispatch(BaseEvent('noop'));
    });

    testWidgets('handler without registered context is ignored', (
      tester,
    ) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              CascadeEventRegistry.registerHandlerBase(
                context,
                CascadeEventHandler<BaseEvent>((_) {
                  calls.add('handled');
                  return true;
                }),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(BaseEvent('x'));
      expect(calls, isEmpty);
    });

    testWidgets('activateContext reorders contexts by recency', (
      tester,
    ) async {
      final calls = <String>[];
      late BuildContext first;
      late BuildContext second;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Builder(
                builder: (context) {
                  first = context;
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandlerBase(
                    context,
                    CascadeEventHandler<BaseEvent>((_) {
                      calls.add('first');
                      return false;
                    }),
                  );
                  return const SizedBox();
                },
              ),
              Builder(
                builder: (context) {
                  second = context;
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandlerBase(
                    context,
                    CascadeEventHandler<BaseEvent>((_) {
                      calls.add('second');
                      return false;
                    }),
                  );
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(BaseEvent('initial'));
      expect(calls, ['second', 'first']);

      calls.clear();
      CascadeEventRegistry.activateContext(first);
      await CascadeEventRegistry.dispatch(BaseEvent('after-activate'));
      expect(calls, ['first', 'second']);

      calls.clear();
      CascadeEventRegistry.activateContext(second);
      await CascadeEventRegistry.dispatch(BaseEvent('after-second-activate'));
      expect(calls, ['second', 'first']);
    });

    testWidgets('registering same type twice overwrites previous handler', (
      tester,
    ) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              CascadeEventRegistry.registerContext(context);
              CascadeEventRegistry.registerHandlerBase(
                context,
                CascadeEventHandler<BaseEvent>((_) {
                  calls.add('old');
                  return true;
                }),
              );
              CascadeEventRegistry.registerHandlerBase(
                context,
                CascadeEventHandler<BaseEvent>((_) {
                  calls.add('new');
                  return true;
                }),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(BaseEvent('value'));
      expect(calls, ['new']);
    });

    testWidgets('unregisterContext removes all event types for that context', (
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
              CascadeEventRegistry.registerHandlerBase(
                context,
                CascadeEventHandler<BaseEvent>((_) {
                  calls.add('base');
                  return true;
                }),
              );
              CascadeEventRegistry.registerHandlerBase(
                context,
                CascadeEventHandler<AnotherEvent>((_) {
                  calls.add('another');
                  return true;
                }),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      CascadeEventRegistry.unregisterContext(tracked);
      await CascadeEventRegistry.dispatch(BaseEvent('x'));
      await CascadeEventRegistry.dispatch(AnotherEvent(1));
      expect(calls, isEmpty);
    });

    testWidgets(
      'exact match returning false does not fall through to supertype handler in same context',
      (tester) async {
        final calls = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                CascadeEventRegistry.registerContext(context);
                CascadeEventRegistry.registerHandlerBase(
                  context,
                  CascadeEventHandler<BaseEvent>((_) {
                    calls.add('super');
                    return true;
                  }),
                );
                CascadeEventRegistry.registerHandlerBase(
                  context,
                  CascadeEventHandler<ChildEvent>((_) {
                    calls.add('exact');
                    return false;
                  }),
                );
                return const SizedBox();
              },
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(ChildEvent('c', 7));
        expect(calls, ['exact']);
      },
    );

    testWidgets('stale unmounted contexts are pruned on dispatch', (
      tester,
    ) async {
      final calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              CascadeEventRegistry.registerContext(context);
              CascadeEventRegistry.registerHandlerBase(
                context,
                CascadeEventHandler<BaseEvent>((_) {
                  calls.add('stale');
                  return true;
                }),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PageCascadeNotifier(
            handlers: [
              CascadeEventHandler<BaseEvent>((_) {
                calls.add('live');
                return true;
              }),
            ],
            child: const SizedBox(),
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(BaseEvent('check-prune'));
      expect(calls, ['live']);
    });

    testWidgets(
      'more recent supertype handler can consume before older exact handler',
      (tester) async {
        final calls = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<ChildEvent>((_) {
                        calls.add('exact-older');
                        return true;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
                Builder(
                  builder: (context) {
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        calls.add('super-newer');
                        return true;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(ChildEvent('payload', 10));
        expect(calls, ['super-newer']);
      },
    );

    testWidgets('unregisterHandler removes only the targeted type', (
      tester,
    ) async {
      final calls = <String>[];
      late BuildContext tracked;
      late CascadeEventHandler<BaseEvent> baseHandler;
      late CascadeEventHandler<AnotherEvent> anotherHandler;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              tracked = context;
              baseHandler = CascadeEventHandler<BaseEvent>((_) {
                calls.add('base');
                return true;
              });
              anotherHandler = CascadeEventHandler<AnotherEvent>((_) {
                calls.add('another');
                return true;
              });

              CascadeEventRegistry.registerContext(context);
              CascadeEventRegistry.registerHandlerBase(context, baseHandler);
              CascadeEventRegistry.registerHandlerBase(context, anotherHandler);
              return const SizedBox();
            },
          ),
        ),
      );

      CascadeEventRegistry.unregisterHandlerBase(tracked, baseHandler);
      await CascadeEventRegistry.dispatch(BaseEvent('removed'));
      expect(calls, isEmpty);

      await CascadeEventRegistry.dispatch(AnotherEvent(42));
      expect(calls, ['another']);
    });

    testWidgets('high-volume contexts dispatch in deterministic MRU order', (
      tester,
    ) async {
      const total = 50;
      final calls = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            children: List.generate(total, (index) {
              return Builder(
                builder: (context) {
                  CascadeEventRegistry.registerContext(context);
                  CascadeEventRegistry.registerHandlerBase(
                    context,
                    CascadeEventHandler<BaseEvent>((_) {
                      calls.add(index);
                      return false;
                    }),
                  );
                  return const SizedBox(height: 1);
                },
              );
            }),
          ),
        ),
      );

      await CascadeEventRegistry.dispatch(BaseEvent('bulk'));
      expect(calls.length, total);
      expect(calls.first, total - 1);
      expect(calls.last, 0);
    });

    testWidgets(
      'high-volume dispatch short-circuits at most recent consumer',
      (tester) async {
        const total = 60;
        var callCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ListView(
              children: List.generate(total, (index) {
                return Builder(
                  builder: (context) {
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        callCount++;
                        return index == total - 1;
                      }),
                    );
                    return const SizedBox(height: 1);
                  },
                );
              }),
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(BaseEvent('stop-early'));
        expect(callCount, 1);
      },
    );

    testWidgets(
      'handler can unregister its own context during dispatch safely',
      (tester) async {
        final calls = <String>[];
        late BuildContext selfCtx;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        calls.add('older');
                        return false;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
                Builder(
                  builder: (context) {
                    selfCtx = context;
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        calls.add('self');
                        CascadeEventRegistry.unregisterContext(selfCtx);
                        return false;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(BaseEvent('mutate'));
        expect(calls, ['self', 'older']);

        calls.clear();
        await CascadeEventRegistry.dispatch(BaseEvent('after-removal'));
        expect(calls, ['older']);
      },
    );

    testWidgets(
      'handler can unregister another context during dispatch safely',
      (tester) async {
        final calls = <String>[];
        late BuildContext toRemove;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    toRemove = context;
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        calls.add('target');
                        return false;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
                Builder(
                  builder: (context) {
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        calls.add('remover');
                        CascadeEventRegistry.unregisterContext(toRemove);
                        return false;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(BaseEvent('mutate-other'));
        expect(calls, ['remover']);
      },
    );

    testWidgets(
      'context registered during dispatch participates only next dispatch',
      (tester) async {
        final calls = <String>[];
        late BuildContext lateCtx;
        var lateRegistered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    lateCtx = context;
                    return const SizedBox();
                  },
                ),
                Builder(
                  builder: (context) {
                    CascadeEventRegistry.registerContext(context);
                    CascadeEventRegistry.registerHandlerBase(
                      context,
                      CascadeEventHandler<BaseEvent>((_) {
                        calls.add('primary');
                        if (!lateRegistered) {
                          lateRegistered = true;
                          CascadeEventRegistry.registerContext(lateCtx);
                          CascadeEventRegistry.registerHandlerBase(
                            lateCtx,
                            CascadeEventHandler<BaseEvent>((_) {
                              calls.add('late');
                              return false;
                            }),
                          );
                        }
                        return false;
                      }),
                    );
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        await CascadeEventRegistry.dispatch(BaseEvent('first'));
        expect(calls, ['primary']);

        calls.clear();
        await CascadeEventRegistry.dispatch(BaseEvent('second'));
        expect(calls, ['late', 'primary']);
      },
    );
  });

  group('PageCascadeNotifier edge cases', () {
    testWidgets('didUpdateWidget replaces callback for same event type', (
      tester,
    ) async {
      final calls = <String>[];

      List<CascadeEventHandler<dynamic>> handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('old');
          return true;
        }),
      ];

      Widget buildApp() {
        return MaterialApp(
          home: PageCascadeNotifier(
            handlers: handlers,
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      await PageCascadeNotifier.dispatch(BaseEvent('before'));
      expect(calls, ['old']);

      handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('new');
          return true;
        }),
      ];

      await tester.pumpWidget(buildApp());
      calls.clear();
      await PageCascadeNotifier.dispatch(BaseEvent('after'));
      expect(calls, ['new']);
    });

    testWidgets('didUpdateWidget removes handler types no longer present', (
      tester,
    ) async {
      final calls = <String>[];

      List<CascadeEventHandler<dynamic>> handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('base');
          return true;
        }),
        CascadeEventHandler<AnotherEvent>((_) {
          calls.add('another');
          return true;
        }),
      ];

      Widget buildApp() {
        return MaterialApp(
          home: PageCascadeNotifier(
            handlers: handlers,
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildApp());

      handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('base-updated');
          return true;
        }),
      ];

      await tester.pumpWidget(buildApp());

      calls.clear();
      await PageCascadeNotifier.dispatch(AnotherEvent(99));
      expect(calls, isEmpty);

      await PageCascadeNotifier.dispatch(BaseEvent('x'));
      expect(calls, ['base-updated']);
    });

    testWidgets('didUpdateWidget adds newly introduced event types', (
      tester,
    ) async {
      final calls = <String>[];

      List<CascadeEventHandler<dynamic>> handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('base');
          return true;
        }),
      ];

      Widget buildApp() {
        return MaterialApp(
          home: PageCascadeNotifier(
            handlers: handlers,
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildApp());

      handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('base2');
          return true;
        }),
        CascadeEventHandler<AnotherEvent>((_) {
          calls.add('another2');
          return true;
        }),
      ];

      await tester.pumpWidget(buildApp());

      calls.clear();
      await PageCascadeNotifier.dispatch(AnotherEvent(5));
      expect(calls, ['another2']);
    });

    testWidgets(
      'rebuilding with equivalent handler types does not duplicate calls',
      (tester) async {
        var dispatchCount = 0;

        Widget buildApp() {
          return MaterialApp(
            home: PageCascadeNotifier(
              handlers: [
                CascadeEventHandler<BaseEvent>((_) {
                  dispatchCount++;
                  return true;
                }),
              ],
              child: const SizedBox(),
            ),
          );
        }

        await tester.pumpWidget(buildApp());
        await tester.pumpWidget(buildApp());
        await tester.pumpWidget(buildApp());

        await PageCascadeNotifier.dispatch(BaseEvent('once'));
        expect(dispatchCount, 1);
      },
    );

    testWidgets('tab activation changes only after animateTo settles', (
      tester,
    ) async {
      final calls = <String>[];
      late TabController tabController;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            animationDuration: const Duration(milliseconds: 300),
            child: Builder(
              builder: (context) {
                tabController = DefaultTabController.of(context);
                return Column(
                  children: [
                    PageCascadeNotifier(
                      tabController: tabController,
                      tabIndex: 0,
                      handlers: [
                        CascadeEventHandler<BaseEvent>((_) {
                          calls.add('tab0');
                          return true;
                        }),
                      ],
                      child: const SizedBox(),
                    ),
                    PageCascadeNotifier(
                      tabController: tabController,
                      tabIndex: 1,
                      handlers: [
                        CascadeEventHandler<BaseEvent>((_) {
                          calls.add('tab1');
                          return true;
                        }),
                      ],
                      child: const SizedBox(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Establish a deterministic baseline: make tab 1 active first.
      tabController.animateTo(1, duration: const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await PageCascadeNotifier.dispatch(BaseEvent('baseline'));
      expect(calls, ['tab1']);

      calls.clear();
      tabController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear,
      );
      await PageCascadeNotifier.dispatch(BaseEvent('before-settle'));
      expect(calls, ['tab1']);

      calls.clear();
      await tester.pumpAndSettle();
      await PageCascadeNotifier.dispatch(BaseEvent('after-settle'));
      expect(calls, ['tab0']);
    });

    testWidgets('updating handlers to empty removes prior registrations', (
      tester,
    ) async {
      final calls = <String>[];
      List<CascadeEventHandler<dynamic>> handlers = [
        CascadeEventHandler<BaseEvent>((_) {
          calls.add('old');
          return true;
        }),
      ];

      Widget buildApp() {
        return MaterialApp(
          home: PageCascadeNotifier(
            handlers: handlers,
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      handlers = const [];
      await tester.pumpWidget(buildApp());

      await PageCascadeNotifier.dispatch(BaseEvent('no-handlers'));
      expect(calls, isEmpty);
    });

    testWidgets('rapid repeated updates keep latest callback only', (
      tester,
    ) async {
      final calls = <String>[];
      var version = 0;

      Widget buildApp() {
        return MaterialApp(
          home: PageCascadeNotifier(
            handlers: [
              CascadeEventHandler<BaseEvent>((_) {
                calls.add('v$version');
                return true;
              }),
            ],
            child: const SizedBox(),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      for (var i = 1; i <= 5; i++) {
        version = i;
        await tester.pumpWidget(buildApp());
      }

      await PageCascadeNotifier.dispatch(BaseEvent('latest'));
      expect(calls, ['v5']);
    });

    testWidgets(
      'rapid push/pop across three routes maintains active handler',
      (tester) async {
        final calls = <String>[];

        Widget makeRoute(String id, {VoidCallback? onNext}) {
          return PageCascadeNotifier(
            handlers: [
              CascadeEventHandler<BaseEvent>((_) {
                calls.add(id);
                return true;
              }),
            ],
            child: Scaffold(
              body: Center(
                child: ElevatedButton(onPressed: onNext, child: Text('go-$id')),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [CascadeNavigationTracker.instance],
            home: Builder(
              builder: (context) {
                return makeRoute(
                  'A',
                  onNext: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (contextB) {
                          return makeRoute(
                            'B',
                            onNext: () {
                              Navigator.of(contextB).push(
                                MaterialPageRoute(
                                    builder: (_) => makeRoute('C')),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );

        await PageCascadeNotifier.dispatch(BaseEvent('at-A'));
        expect(calls, ['A']);

        calls.clear();
        await tester.tap(find.text('go-A'));
        await tester.pumpAndSettle();
        await PageCascadeNotifier.dispatch(BaseEvent('at-B'));
        expect(calls, ['B']);

        calls.clear();
        await tester.tap(find.text('go-B'));
        await tester.pumpAndSettle();
        await PageCascadeNotifier.dispatch(BaseEvent('at-C'));
        expect(calls, ['C']);

        calls.clear();
        Navigator.of(tester.element(find.byType(Scaffold))).pop();
        await tester.pump();
        await PageCascadeNotifier.dispatch(BaseEvent('back-to-B'));
        expect(calls, ['B']);

        calls.clear();
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(Scaffold))).pop();
        await tester.pump();
        await PageCascadeNotifier.dispatch(BaseEvent('back-to-A'));
        expect(calls, ['A']);
      },
    );
  });
}
