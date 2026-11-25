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

  test('the logs end note and the offline headline agree with one', () {
    expect(de.serverCareLogsLastLines(1), 'Das ist die letzte Zeile.');
    expect(de.serverCareLogsLastLines(500), 'Das sind die letzten 500 Zeilen.');
    expect(en.serverCareLogsLastLines(1), "That's the last line.");
    expect(en.serverCareLogsLastLines(500), "That's the last 500 lines.");
    expect(
      de.serverCareHeadlineChannelsOfflineCount(1, 1),
      '1 von 1 Messaging-Kanal ist offline',
    );
    expect(
      de.serverCareHeadlineChannelsOfflineCount(1, 2),
      '1 von 2 Messaging-Kanälen ist offline',
    );
    expect(
      de.serverCareHeadlineChannelsOfflineCount(2, 2),
      '2 von 2 Messaging-Kanälen sind offline',
    );
    expect(
      en.serverCareHeadlineChannelsOfflineCount(1, 1),
      '1 of 1 messaging channel is offline',
    );
    expect(
      en.serverCareHeadlineChannelsOfflineCount(1, 2),
      '1 of 2 messaging channels is offline',
    );
    expect(
      en.serverCareHeadlineChannelsOfflineCount(2, 2),
      '2 of 2 messaging channels are offline',
    );
  });

  test('the models counter label agrees with done and total', () {
    expect(
      de.chatActivityLineReferencesCounterLabel(1, 3),
      '1 von 3 Modellen hat geantwortet',
    );
    expect(
      de.chatActivityLineReferencesCounterLabel(3, 3),
      '3 von 3 Modellen haben geantwortet',
    );
    expect(
      de.chatActivityLineReferencesCounterLabel(1, 1),
      '1 von 1 Modell hat geantwortet',
    );
    expect(
      en.chatActivityLineReferencesCounterLabel(1, 1),
      '1 of 1 model answered',
    );
    expect(
      en.chatActivityLineReferencesCounterLabel(2, 3),
      '2 of 3 models answered',
    );
  });
}
