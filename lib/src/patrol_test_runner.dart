import 'dart:async';

import 'package:bdd_framework/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// A function type that represents a code block in a Patrol integration test,
/// providing access to both the [BddContext] and the [PatrolIntegrationTester].
typedef PatrolTestCallback = FutureOr<void> Function(
  BddContext ctx,
  PatrolIntegrationTester patrolTester,
);

/// The Patrol-specific [BddContext] that carries the active
/// [PatrolIntegrationTester].
class BddPatrolContext extends BddContext {
  BddPatrolContext._(
    BddTableValues example,
    BddMultipleTableValues tables, {
    required this.patrolTester,
  }) : super(example, tables);

  /// Creates a Patrol-aware context from an existing [BddContext].
  factory BddPatrolContext.from(
    BddContext context, {
    required PatrolIntegrationTester patrolTester,
  }) {
    return BddPatrolContext._(
      context.example,
      context.tables,
      patrolTester: patrolTester,
    );
  }

  final PatrolIntegrationTester patrolTester;
}

/// Extension providing the standard `.run()` method for Patrol BDD tests.
///
/// Use this entry point when you are writing integration tests that require
/// Patrol's native automation and enhanced finders.
extension PatrolTestRun on BddRunnable {
  /// Executes the BDD scenario as a Patrol integration test.
  ///
  /// This method injects the [PatrolIntegrationTester] directly into the `BddContext`
  /// and wraps the execution with [patrolTest].
  void run([PatrolTestCallback? testCallback]) {
    BddRunner().run(
      bdd,
      (ctx) async {
        final patrolTester = _patrolContextOf(ctx).patrolTester;
        if (testCallback != null) await testCallback(ctx, patrolTester);
        _failOnPendingFlutterError(patrolTester.tester);
      },
      _testDelegate,
      _errorHandler,
    );
  }
}

/// Extension to attach Patrol-specific executable closures (code blocks) to BDD terms.
///
/// By importing `bdd_framework_patrol.dart`, these extensions become available,
/// allowing you to access the [PatrolIntegrationTester] (often named `$`) in every step.
extension PatrolTestCode<T> on BddCodeable<T> {
  /// Attaches a code block that injects the [PatrolIntegrationTester] directly into the callback.
  ///
  /// The [codeRun] function receives both the [BddContext] and the [PatrolIntegrationTester]
  /// currently active for the test.
  T code(PatrolTestCallback codeRun) {
    return addCode((ctx) async {
      final patrolTester = _patrolContextOf(ctx).patrolTester;
      await codeRun(ctx, patrolTester);
      _failOnPendingFlutterError(patrolTester.tester);
    });
  }
}

/// The errors Flutter reported (and didn't ignore) since the last check.
final _reportedErrors = <FlutterErrorDetails>[];

/// Thrown when Flutter reported an error during a step, such as a layout
/// overflow, without throwing it.
class _FlutterErrorReported implements Exception {
  _FlutterErrorReported(this.details);

  final FlutterErrorDetails details;

  @override
  String toString() => details.exceptionAsString();
}

/// Flutter doesn't throw errors reported while building or laying out widgets.
/// It keeps them, and only fails the test after the test body ends, so the
/// BDD would print "PASSED" for a failed test. Checking after each step makes
/// the step fail right away instead, with the original error.
///
/// An error the test already consumed with [WidgetTester.takeException]
/// is not pending anymore, so it doesn't fail the step.
void _failOnPendingFlutterError(WidgetTester tester) {
  final errors = List.of(_reportedErrors);
  _reportedErrors.clear();
  final pending = tester.takeException();
  if (pending == null) return;
  final details = errors.lastWhere(
    (details) => identical(details.exception, pending),
    // With several errors, Flutter keeps one summary error pending, and has
    // already printed each of them.
    orElse: () => FlutterErrorDetails(
        exception: pending, library: 'Flutter test framework'),
  );
  throw _FlutterErrorReported(details);
}

/// Internal helper that bridges the [BddRunner] to the Patrol [patrolTest] function.
void _testDelegate(TestInvocation invocation) {
  if (invocation.only) _warnOnlyIsNotSupported(invocation.description);

  patrolTest(
    invocation.description,
    (patrolTester) async {
      _trackFlutterErrors();
      invocation.transformContext?.call(
        (context) => BddPatrolContext.from(
          context,
          patrolTester: patrolTester,
        ),
      );

      try {
        await invocation.body();
      } finally {
        _cleanTargetPlatformOverride();
      }
    },
    skip: invocation.skip,
    timeout: invocation.timeout,
    tags: invocation.tags,
  );
}

BddPatrolContext _patrolContextOf(BddContext context) {
  if (context is BddPatrolContext) {
    return context;
  }

  throw StateError(
    'PatrolIntegrationTester not found in BddContext. '
    'Did you forget to use ".run()" imported from '
    '`package:bdd_framework_patrol/bdd_framework_patrol.dart` '
    'at the end of the scenario?',
  );
}

void _errorHandler(Object error, StackTrace stackTrace) {
  var errorDetails = (error is _FlutterErrorReported)
      ? error.details
      : FlutterErrorDetails(
          library: 'BDD Framework',
          exception: error,
          stack: stackTrace,
          stackFilter: _stackFilter,
        );
  reportTestException(errorDetails, "");
}

Iterable<String> _stackFilter(Iterable<String> frames) {
  // Removes the frames we are not interested in.
  var filteredFrames = frames.where((frame) =>
      !frame.contains("package:matcher/") &&
      !frame.contains("package:flutter_test/") &&
      !frame.contains("package:patrol/") &&
      !frame.contains("package:bdd_framework/src/") &&
      !frame.contains("package:test_api/src/"));

  return FlutterError.defaultStackFilter(filteredFrames);
}

/// Wraps Flutter's error handler to keep the errors it reports, so each step
/// can check them. When [BddPatrol.ignoreOverflow] is on, RenderFlex overflow
/// errors are only printed.
void _trackFlutterErrors() {
  _reportedErrors.clear();
  var ignoreOverflow = BddPatrol.ignoreOverflow;
  var handlerOriginal = FlutterError.onError;
  FlutterError.onError = (details) {
    if (ignoreOverflow && _isOverflow(details)) {
      FlutterError.dumpErrorToConsole(details);
      return;
    }
    _reportedErrors.add(details);
    handlerOriginal!(details);
  };
}

bool _isOverflow(FlutterErrorDetails details) {
  var exception = details.exception;
  return (exception is FlutterError) &&
      exception.diagnostics
          .map((diagnostic) => diagnostic.value)
          .whereType<List<Object>>()
          .expand((value) => value)
          .any((data) => data.toString().startsWith("A RenderFlex overflowed by"));
}

/// `Bdd(feature).only` can't work with Patrol. It relies on the `solo` flag of
/// `package:test`, which would also skip the `patrol_test_explorer` test that
/// Patrol's generated test bundle needs to run first, so no tests would run.
/// The test runs normally instead, and so do the others.
void _warnOnlyIsNotSupported(String description) {
  // ignore: avoid_print
  print('Warning: `.only` is not supported by bdd_framework_patrol, so it is '
      'ignored in "$description", and all the tests run. To run a single '
      'Patrol test file, use: patrol test --target <file>');
}

void _cleanTargetPlatformOverride() => (debugDefaultTargetPlatformOverride = null);

/// Configuration for Patrol-specific BDD settings.
class BddPatrol {
  /// Whether to suppress RenderFlex overflow errors in logs.
  static bool ignoreOverflow = true;
}
