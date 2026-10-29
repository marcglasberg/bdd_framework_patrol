import 'dart:async';

import 'package:bdd_framework_patrol/bdd_framework_patrol.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  var feature = BddFeature('Patrol Test Runner');

  group('context transformation', () {
    test('creates a patrol context from an existing bdd context', () {
      final baseContext = BddContext(
        BddTableValues({'name': 'demo'}),
        BddMultipleTableValues({}),
      );
      final patrolTester = _FakePatrolIntegrationTester();

      final patrolContext = BddPatrolContext.from(
        baseContext,
        patrolTester: patrolTester,
      );

      expect(patrolContext.example.val('name'), 'demo');
      expect(patrolContext.patrolTester, same(patrolTester));
    });

    testWidgets('patrol code receives transformed patrol context',
        (tester) async {
      final bdd = Bdd(feature)
          .scenario('Patrol context transformation')
          .given('A patrol code block')
          .code((ctx, patrolTester) {
            expect(ctx, isA<BddPatrolContext>());
            expect((ctx as BddPatrolContext).patrolTester, same(patrolTester));
          })
          .when('The runner transforms the context')
          .then('The patrol tester is available in the code block')
          .bdd;

      final patrolTester = _FakePatrolIntegrationTester(tester);
      final invocations = <TestInvocation>[];

      BddRunner().run(
        bdd,
        (ctx) {
          expect(ctx, isA<BddPatrolContext>());
          expect((ctx as BddPatrolContext).patrolTester, same(patrolTester));
        },
        invocations.add,
        null,
      );
      final invocation = invocations.single;
      invocation.transformContext?.call(
        (context) => BddPatrolContext.from(
          context,
          patrolTester: patrolTester,
        ),
      );
      await invocation.body();

      expect(bdd.passed, [true]);
    });
  });

  group('scenario entry points', () {
    for (final keyword in ['When', 'Then']) {
      testWidgets('transforms Patrol context for a $keyword start',
          (widgetTester) async {
        final bdd = Bdd(feature);
        final scenario = bdd.scenario('Patrol $keyword entry');
        final tester = _FakePatrolIntegrationTester(widgetTester);
        PatrolIntegrationTester? received;
        final PatrolTestCallback callback = (ctx, patrolTester) {
          received = patrolTester;
          expect((ctx as BddPatrolContext).patrolTester, same(tester));
        };
        if (keyword == 'When') {
          scenario.when('action').code(callback);
        } else {
          scenario.then('outcome').code(callback);
        }
        final invocations = <TestInvocation>[];
        BddRunner().run(bdd, (_) {}, invocations.add, null, () => true);
        final invocation = invocations.single;
        invocation.transformContext!(
            (context) => BddPatrolContext.from(context, patrolTester: tester));
        await invocation.body();
        expect(received, same(tester));
        expect(bdd.passed, [true]);
      });
    }
  });

  group('errors Flutter reports without throwing', () {
    // Runs [bdd] in the current widget test, with a fake Patrol tester.
    Future<List<Object>> runBdd(BddFramework bdd, WidgetTester tester) async {
      final errors = <Object>[];
      final invocations = <TestInvocation>[];
      BddRunner().run(bdd, (_) {}, invocations.add,
          (error, stackTrace) => errors.add(error));
      final invocation = invocations.single;
      invocation.transformContext!((context) => BddPatrolContext.from(context,
          patrolTester: _FakePatrolIntegrationTester(tester)));
      await invocation.body();
      return errors;
    }

    testWidgets('fail the step, and the steps after it do not run',
        (tester) async {
      final log = <String>[];
      final bdd = Bdd(feature)
          .scenario('Flutter reports an error')
          .given('A step where Flutter reports an error')
          .code((ctx, patrolTester) {
            log.add('given');
            FlutterError.reportError(FlutterErrorDetails(
                exception: FlutterError('expected reported error')));
          })
          .when('A later step')
          .code((ctx, patrolTester) => log.add('when'))
          .then('It does not run')
          .bdd;

      final errors = await runBdd(bdd, tester);

      expect(log, ['given']);
      expect(bdd.passed, [false]);
      expect(errors.single.toString(), contains('expected reported error'));
      // The step took the error, so the widget test itself does not fail.
      expect(tester.takeException(), isNull);
    });

    testWidgets('do not fail the step when the test takes them',
        (tester) async {
      final bdd = Bdd(feature)
          .scenario('The test takes the error')
          .given('A step where Flutter reports an error')
          .code((ctx, patrolTester) {
            FlutterError.reportError(FlutterErrorDetails(
                exception: FlutterError('expected and handled')));
            expect(patrolTester.tester.takeException(), isA<FlutterError>());
          })
          .when('A later step')
          .then('The test passes')
          .bdd;

      final errors = await runBdd(bdd, tester);

      expect(errors, isEmpty);
      expect(bdd.passed, [true]);
    });
  });

  group('misuse feedback', () {
    test('throws a helpful error when patrol code runs without patrol runner',
        () async {
      final reporter = _NoOpBddReporter();

      final error = await _captureAsyncError(() {
        Bdd(feature)
            .scenario('Patrol code without patrol runner')
            .given('A patrol-specific code step')
            .code((ctx, patrolTester) {})
            .when('The scenario runs through testRun')
            .then('A helpful error is thrown')
            .testRun((ctx) {}, reporter);
      });

      expect(
        error,
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('PatrolIntegrationTester not found in BddContext'),
        ),
      );
    });
  });
}

class _NoOpBddReporter extends BddReporter {
  @override
  Future<void> report() async {}
}

class _FakePatrolIntegrationTester implements PatrolIntegrationTester {
  _FakePatrolIntegrationTester([this._tester]);

  final WidgetTester? _tester;

  @override
  WidgetTester get tester =>
      _tester ?? (throw StateError('This fake has no WidgetTester.'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Object> _captureAsyncError(void Function() action) async {
  final completer = Completer<Object>();

  await runZonedGuarded(() async {
    action();
    await Future<void>.delayed(Duration.zero);
  }, (error, stackTrace) {
    if (!completer.isCompleted) {
      completer.complete(error);
    }
  });

  return completer.future;
}
