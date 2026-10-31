import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/sign_in_browser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hermes_app/web_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  Object? startAnswer;

  setUp(() {
    calls = [];
    startAnswer = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start') {
        final answer = startAnswer;
        if (answer is PlatformException) throw answer;
        return startAnswer;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> sendFromNative(String method) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method)),
    (_) {},
  );

  test('starts a session that ends at the finished address', () async {
    final browser = AuthSessionBrowser();

    final opened = await browser.open(
      Uri.parse('https://hermes.test/auth/native/authorize?state=s'),
      onDismissed: () {},
    );

    expect(opened, isTrue);
    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {
      'url': 'https://hermes.test/auth/native/authorize?state=s',
      'callbackScheme': AuthSessionBrowser.callbackScheme,
    });
    expect(browser.finishedRedirect.scheme, AuthSessionBrowser.callbackScheme);
  });

  test('reports the user closing the sheet', () async {
    var dismissed = 0;
    await AuthSessionBrowser().open(
      Uri.parse('https://hermes.test/'),
      onDismissed: () => dismissed++,
    );

    await sendFromNative('dismissed');

    expect(dismissed, 1);
  });

  test('closing cancels the session and stops listening', () async {
    var dismissed = 0;
    final browser = AuthSessionBrowser();
    await browser.open(
      Uri.parse('https://hermes.test/'),
      onDismissed: () => dismissed++,
    );

    await browser.close();
    await sendFromNative('dismissed');

    expect(calls.last.method, 'cancel');
    expect(dismissed, 0);
  });

  test('a session that cannot start is reported as not opened', () async {
    startAnswer = false;
    expect(
      await AuthSessionBrowser().open(
        Uri.parse('https://hermes.test/'),
        onDismissed: () {},
      ),
      isFalse,
    );

    startAnswer = PlatformException(code: 'bad_arguments');
    expect(
      await AuthSessionBrowser().open(
        Uri.parse('https://hermes.test/'),
        onDismissed: () {},
      ),
      isFalse,
    );
  });

  test('a session that cannot start stops listening for dismissals', () async {
    startAnswer = false;
    var dismissed = 0;
    await AuthSessionBrowser().open(
      Uri.parse('https://hermes.test/'),
      onDismissed: () => dismissed++,
    );

    await sendFromNative('dismissed');

    expect(dismissed, 0);
  });

  test('a flow that ends late leaves a newer sheet alone', () async {
    var olderDismissed = 0;
    var newerDismissed = 0;
    final older = AuthSessionBrowser();
    await older.open(
      Uri.parse('https://hermes.test/1'),
      onDismissed: () => olderDismissed++,
    );
    final newer = AuthSessionBrowser();
    await newer.open(
      Uri.parse('https://hermes.test/2'),
      onDismissed: () => newerDismissed++,
    );

    await older.close();
    expect(calls.where((c) => c.method == 'cancel'), isEmpty);

    await sendFromNative('dismissed');
    expect(olderDismissed, 0);
    expect(newerDismissed, 1);

    await newer.close();
    expect(calls.last.method, 'cancel');
  });

  group('FallbackSignInBrowser', () {
    test('uses the sheet when it opens', () async {
      final browser = FallbackSignInBrowser(
        AuthSessionBrowser(),
        _RecordingBrowser(),
      );

      expect(
        await browser.open(
          Uri.parse('https://hermes.test/'),
          onDismissed: () {},
        ),
        isTrue,
      );
      expect(browser.fellBack, isFalse);
      expect(
        browser.finishedRedirect?.scheme,
        AuthSessionBrowser.callbackScheme,
      );

      await browser.close();
      expect(calls.last.method, 'cancel');
    });

    test('opens the fallback when the sheet is refused', () async {
      startAnswer = false;
      final fallback = _RecordingBrowser();
      final browser = FallbackSignInBrowser(AuthSessionBrowser(), fallback);

      expect(
        await browser.open(
          Uri.parse('https://hermes.test/'),
          onDismissed: () {},
        ),
        isTrue,
      );
      expect(browser.fellBack, isTrue);
      expect(fallback.opened, [Uri.parse('https://hermes.test/')]);
      expect(browser.finishedRedirect, isNull);

      await browser.close();
      expect(fallback.closed, 1);
      expect(calls.where((c) => c.method == 'cancel'), isEmpty);
    });
  });
}

class _RecordingBrowser implements SignInBrowser {
  final opened = <Uri>[];
  var closed = 0;

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) async {
    opened.add(url);
    return true;
  }

  @override
  Future<void> close() async => closed++;

  @override
  Uri? get finishedRedirect => null;
}
