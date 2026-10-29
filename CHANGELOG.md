## 1.0.1

* An error Flutter reports without throwing it, like a layout overflow when
  `BddPatrol.ignoreOverflow` is `false`, now fails the step where it happens.
  Previously the BDD printed `TEST PASSED!` and Flutter failed the test only
  afterwards. The steps after it don't run, and the error is shown with its
  original details. An error the test takes itself with
  `$.tester.takeException()` doesn't fail the step.

* `Bdd(feature).only` (from `bdd_framework` 5.1.0) is not supported with
  Patrol, because it would also skip the test Patrol uses to discover the other
  tests. A test marked with `.only` now prints a warning and runs normally.

* Requires `bdd_framework` 5.1.0.

## 1.0.0

* Initial version. The Patrol runner was moved here from `bdd_framework`
  (`package:bdd_framework/patrol_test.dart`), so that `bdd_framework` itself no
  longer depends on Patrol. Import
  `package:bdd_framework_patrol/bdd_framework_patrol.dart` instead.
