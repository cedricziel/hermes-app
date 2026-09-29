import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where a sign-in page is shown. The authorization code always comes back
/// through the loopback listener; the browser only has to show the page.
abstract class SignInBrowser {
  /// The browser for this platform: an [AuthSessionBrowser] on iOS and macOS,
  /// the external browser elsewhere.
  factory SignInBrowser.platform() => Platform.isIOS || Platform.isMacOS
      ? AuthSessionBrowser()
      : const ExternalBrowser();

  /// Shows [url]. Returns false when nothing could be opened.
  ///
  /// [onDismissed] runs when the user closes the browser before the sign-in
  /// reached the loopback listener. A browser that cannot tell never runs it.
  Future<bool> open(Uri url, {required void Function() onDismissed});

  /// Closes what [open] showed, when it is still open.
  Future<void> close();

  /// Where the loopback listener sends the browser once the sign-in reached
  /// it. Null answers with a page saying the tab can be closed.
  Uri? get finishedRedirect;
}

/// Opens the sign-in page in the system's default browser.
class ExternalBrowser implements SignInBrowser {
  const ExternalBrowser();

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<void> close() async {}

  @override
  Uri? get finishedRedirect => null;
}

/// Shows the sign-in page in an `ASWebAuthenticationSession` sheet
/// (`WebAuthSession.swift` in the iOS and macOS runners), the way App Review
/// expects an app to sign in on the web.
///
/// Hermes only accepts a loopback redirect, so the code still reaches the
/// listener. The listener then redirects the sheet to [callbackScheme],
/// which ends the session and closes the sheet.
class AuthSessionBrowser implements SignInBrowser {
  AuthSessionBrowser({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('hermes_app/web_auth');

  static const callbackScheme = 'hermes-app-signin';

  final MethodChannel _channel;

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'dismissed') onDismissed();
    });
    try {
      return await _channel.invokeMethod<bool>('start', {
            'url': url.toString(),
            'callbackScheme': callbackScheme,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> close() async {
    _channel.setMethodCallHandler(null);
    await _channel.invokeMethod<void>('cancel');
  }

  @override
  Uri get finishedRedirect => Uri.parse('$callbackScheme://signed-in');
}
