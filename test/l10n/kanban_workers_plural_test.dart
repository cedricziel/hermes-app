import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('German workers count agrees with the number', () {
    expect(de.kanbanWorkersRunning(1), '1 läuft');
    expect(de.kanbanWorkersRunning(3), '3 laufen');
    expect(de.kanbanWorkersRunning(0), '0 laufen');
  });

  test('English workers count reads the same for any number', () {
    expect(en.kanbanWorkersRunning(1), '1 running');
    expect(en.kanbanWorkersRunning(3), '3 running');
  });
}
