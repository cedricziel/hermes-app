import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/models/hermes_status.dart';

void main() {
  group('HermesStatus.fromJson', () {
    test('defaults absent fields', () {
      final status = HermesStatus.fromJson(const {});
      expect(status.authRequired, isFalse);
      expect(status.authFlows, isEmpty);
      expect(status.version, isNull);
    });

    test('rejects wrongly typed fields with a FormatException', () {
      for (final json in <Map<String, dynamic>>[
        {'auth_required': 'yes'},
        {'auth_flows': 'native_pkce'},
        {'auth_providers': 3},
        {'version': 1},
      ]) {
        expect(
          () => HermesStatus.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  group('HermesIdentity.fromJson', () {
    test('defaults absent fields', () {
      expect(HermesIdentity.fromJson(const {}).userId, '');
    });

    test('rejects wrongly typed fields with a FormatException', () {
      expect(
        () => HermesIdentity.fromJson(const {'user_id': 7}),
        throwsFormatException,
      );
      expect(
        () => HermesIdentity.fromJson(const {'email': <String>[]}),
        throwsFormatException,
      );
    });
  });
}
