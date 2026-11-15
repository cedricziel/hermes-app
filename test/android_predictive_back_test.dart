import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android 13 to 15 only route the back gesture through Flutter's predictive
/// back handling when the application opts in; Android 16 enables it by
/// default at targetSdk 36. Without the attribute the page transitions the
/// theme keeps never get their peek animation there.
void main() {
  test('the application opts in to predictive back', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final application = RegExp(r'<application\b[^>]*>').firstMatch(manifest);

    expect(application, isNotNull);
    expect(
      application!.group(0),
      contains('android:enableOnBackInvokedCallback="true"'),
    );
  });
}
