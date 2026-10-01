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
        if (testCallback != null) {
          await testCallback(ctx, _patrolContextOf(ctx).patrolTester);
        }
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
      await codeRun(ctx, _patrolContextOf(ctx).patrolTester);
    });
  }
}

/// Internal helper that bridges the [BddRunner] to the Patrol [patrolTest] function.
void _testDelegate(TestInvocation invocation) {
  patrolTest(
    invocation.description,
    (patrolTester) async {
      if (BddPatrol.ignoreOverflow) _ignoreOverflowErrors();
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
  var errorDetails = FlutterErrorDetails(
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

void _ignoreOverflowErrors() {
  var handlerOriginal = FlutterError.onError;
  FlutterError.onError = (details) {
    var exception = details.exception;
    var ifOverflow = (exception is FlutterError) &&
        exception.diagnostics
            .map((diagnostic) => diagnostic.value)
            .whereType<List<Object>>()
            .expand((value) => value)
            .any((data) => data.toString().startsWith("A RenderFlex overflowed by"));

    if (ifOverflow)
      FlutterError.dumpErrorToConsole(details);
    else
      handlerOriginal!(details);
  };
}

void _cleanTargetPlatformOverride() => (debugDefaultTargetPlatformOverride = null);

/// Configuration for Patrol-specific BDD settings.
class BddPatrol {
  /// Whether to suppress RenderFlex overflow errors in logs.
  static bool ignoreOverflow = true;
}
