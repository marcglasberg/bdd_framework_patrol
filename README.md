# bdd_framework_patrol

[Patrol](https://pub.dev/packages/patrol) integration for
[bdd_framework](https://pub.dev/packages/bdd_framework).

The code in this package was contributed by [Kahoulam](https://github.com/Kahoulam).

Write BDD scenarios with `bdd_framework` and run them as Patrol integration tests.
Every `.code()` step and the final `.run()` callback receive the
`PatrolIntegrationTester` (usually named `$`).

This runner is a separate package so that `bdd_framework` itself doesn't depend
on Patrol. Add it only to projects that use Patrol.

## Install

```yaml
dev_dependencies:
  bdd_framework_patrol: ^1.0.0
  patrol: ^4.5.0
```

Then set up Patrol itself (native configuration, the `patrol:` section in your
app's `pubspec.yaml`, and the `patrol_cli`) as described in the
[Patrol documentation](https://patrol.leancode.co).

## Usage

Import `bdd_framework_patrol.dart` **instead of** the other `bdd_framework`
runners (`dart_test.dart`, `flutter_test.dart`, `flutter_widget_test.dart`). It
re-exports the whole BDD API.

```dart
import 'package:bdd_framework_patrol/bdd_framework_patrol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Greeting');

  Bdd(feature)
      .scenario('Shows a greeting.')
      .given('The app is started.')
      .code((ctx, $) async {
    await $.tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Hello')),
    ));
  })
      .when('The user looks at the screen.')
      .then('The greeting is visible.')
      .run((ctx, $) async {
    expect($('Hello'), findsOneWidget);
  });
}
```

Example and table values work as usual, through `ctx.example` and `ctx.table()`.

Run the tests with `patrol test`. The unit tests in `test/` run with
`flutter test`.

By default, `RenderFlex` overflow errors are printed but don't fail the test. Set
`BddPatrol.ignoreOverflow = false` to make them fail it.

## Security note

Patrol is a device-automation tool. While a Patrol test runs, it starts local
test-control services: a Dart test service (default port 8082) and a native
automation service (default port 8081). They have no authentication. Depending on
the device and network setup, other machines may be able to reach them. Run
Patrol tests on test devices and networks you trust, with non-sensitive data. The
Patrol CLI also collects analytics by default. Set `PATROL_ANALYTICS_ENABLED=false`
to turn it off.

None of this happens when you only import package `bdd_framework`.
