import 'package:bdd_framework_patrol/bdd_framework_patrol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Patrol Test Runner');

  group('run', () {
    Bdd(feature)
        .scenario('Provides PatrolIntegrationTester to run callback')
        .given('A BDD scenario with a patrol test callback')
        .when('The run method is invoked')
        .then('The PatrolIntegrationTester is available and functional')
        .run((ctx, $) async {
      await $.tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Hello BDD with Patrol')),
      ));
      expect($('Hello BDD with Patrol'), findsOneWidget);
    });

    Bdd(feature)
        .scenario('Runs without callback')
        .given('A BDD scenario')
        .when('Run is invoked without a callback')
        .then('No error occurs')
        .run();
  });

  group('code steps', () {
    Bdd(feature)
        .scenario('Provides PatrolIntegrationTester in code step')
        .given('A scenario with a patrol code block')
        .code((ctx, $) async {
          await $.tester.pumpWidget(const MaterialApp(
            home: Scaffold(body: Text('Code Step')),
          ));
          expect($('Code Step'), findsOneWidget);
        })
        .when('The code step executes')
        .then('The tester is available')
        .run();

    var step1Ran = false;
    var step2Ran = false;
    Bdd(feature)
        .scenario('Multiple code steps all receive tester')
        .given('A scenario with multiple patrol code blocks')
        .code((ctx, $) async {
          step1Ran = true;
          await $.tester.pumpWidget(const MaterialApp(
            home: Scaffold(body: Text('Step 1')),
          ));
          expect($('Step 1'), findsOneWidget);
        })
        .when('Each step uses the tester')
        .code((ctx, $) async {
          step2Ran = true;
          await $.tester.pumpWidget(const MaterialApp(
            home: Scaffold(body: Text('Step 2')),
          ));
          expect($('Step 2'), findsOneWidget);
        })
        .then('All steps executed with a valid tester')
        .run((ctx, $) async {
          expect(step1Ran, isTrue);
          expect(step2Ran, isTrue);
        });
  });

  group('example values', () {
    Bdd(feature)
        .scenario('Accesses example values in patrol test')
        .given('A scenario with <label>')
        .when('The widget displays the example value')
        .then('The example value drives the widget content')
        .example(val('label', 'Alpha'))
        .example(val('label', 'Beta'))
        .run((ctx, $) async {
      final label = ctx.example.val('label') as String;
      await $.tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Text(label)),
      ));
      expect($(label), findsOneWidget);
    });
  });

  group('table values', () {
    Bdd(feature)
        .scenario('Accesses table values in patrol test')
        .given('A scenario with a data table')
        .table(
          'items',
          row(val('name', 'widget_a'), val('visible', true)),
          row(val('name', 'widget_b'), val('visible', false)),
        )
        .when('The code reads from ctx.table')
        .then('The table data is accessible')
        .run((ctx, $) async {
      expect(ctx.table('items').row(0).val('name'), 'widget_a');
      expect(ctx.table('items').row(0).val('visible'), true);
      expect(ctx.table('items').row(1).val('name'), 'widget_b');
      expect(ctx.table('items').row(1).val('visible'), false);
    });
  });
}
